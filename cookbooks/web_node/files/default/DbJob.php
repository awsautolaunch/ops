<?php

namespace AppBundle\App;
require_once '/var/www/html/current/symfony/src/AppBundle/App/lib/Ec2Client.php';

Class DbJob{

    private $ec2;
    public function runJob($job_file) {
        $this->ec2 = new Ec2Client('us-west-2','latest');
        $working_nodes = $this->getWorkingNodes('cloudinit');
        $running_nodes = $this->ec2->getInstanceIDs('db_node');
    
        $max_retries = 15;
        $non_working_nodes = array_diff($running_nodes, $working_nodes);
        if (count($non_working_nodes) !== 0) {
            while($max_retries > 0) {
                $max_retries--;
                $boot_completed_nodes = $this->getWorkingNodes('bootcompleted');
                if (count(array_diff($non_working_nodes, $boot_completed_nodes)) !== 0) {
                    sleep(20);
                } else {
                    break;
                }
            }
        }

        $working_nodes = $this->getWorkingNodes('cloudinit');
        $this->pushConfig($working_nodes);
        unlink($job_file);
    }

    private function getWorkingNodes($tag_name, $role_name="db_node") {
        $filters = $this->getFilter($tag_name, $role_name);
        $result = $this->ec2->describeInstances($filters);
        $reservations = $result->toArray();
        $instanceIDs = $this->ec2->getInstancesDetails($reservations['Reservations']);
        return $instanceIDs;
    }

    private function getFilter($tag_name, $role_name) {
        $filter = array(
            array(
                'Name' => 'tag:group_name',
                'Values' => array($role_name)
            ),
            array(
                'Name' => 'instance-state-code',
                'Values' => array(16)
            ),
            array(
                'Name' => "tag:$tag_name",
                'Values' => array('true')
            )
        );

        return $filter;

    }
    
    private function getPcpCount() {
        $command = 'pcp_node_count 10 localhost 9898 postgres wordpass1';
        $output = array();
        exec($command, $output);
        return $output[0];

    }

    private function getMapping($db_ips) {
        $mapping = array();
        $count = $this->getPcpCount();
        $master = $this->findMaster($db_ips);

        if (is_array($master) && count($master) > 1) {
            $this->exitWithError("Multiple Masters found, manual intervention needed.");
        }   

        if ($count === 0)  {
            $master = findMaster($db_ips);
            if ($master == false) {
                $mapping['master'] = $db_ips[0];
                unset($db_ips[0]);
                $mapping['slave'] = $db_ips;
            } else {
                $mapping['master'] = $master[0];
                $mapping['slave'] = array_diff($db_ips, $master);
            }   

            $this->setupReplication($mapping['master'], $mapping['slave']);
            $mapping = $this->convertToMappingArray($mapping);
        } else {
            if ($count !== count($db_ips)) {
                $node_id_mapping = array();
                $mapping['master'] = $master[0];
                for ($i=0; $i<$count ; $i++) {
                    $node_id_mapping[$i] = $this->getPcpNodeIp($i);
                }   
                $unaccounted_servers = array_diff($db_ips, $node_id_mapping);
                $unused_node_ids = array_keys(array_diff_key($db_ips, $node_id_mapping));
                $this->setupReplication($mapping['master'], $unaccounted_servers);
                $this->assignNodeIds($unused_node_ids, $unaccounted_servers, $node_id_mapping);
                $mapping = $node_id_mapping;
                    
            } else {
                $this->exitWithError("Config is good.");
            }   
        }   
        return $mapping;
    }

    private function getPcpNodeIp ($node_id) {
        $format = 'pcp_node_info 10 localhost 9898 postgres wordpass1 %s';
        $command = sprintf($format, $node_id);
        $output = array();
        exec($command, $output);
        if (is_array($output)) {
            $ip = split(" ", $output[0])[0];
        } else {
            $ip = false;
        }   
        
            
        return $ip;
    }
    private function generateConfigFile($mapping) {
        $template_file = "/etc/pgpool-II/pgpool.conf.tmpl";
        $conf_content = file($template_file);
        foreach ($mapping as $id => $ip) {
            $conf_content[] = "backend_hostname$id = '$ip'";
            $conf_content[] = "backend_port$id = 5432";
            $conf_content[] = "backend_weight$id = 1";
            $conf_content[] = "backend_flag$id = 'ALLOW_TO_FAILOVER'";
        }   
        return implode("\n",$conf_content);
    }

    private function getConfigurationFile($db_ips){
        $mapping = $this->getMapping($db_ips);
        return $this->generateConfigFile($mapping);
    }

    private function pushConfig($instanceIds) {
        $db_ips = $this->ec2->getInstanceIPs($instanceIds);
        $web_nodes = $this->getWorkingNodes('cloudinit','web_node');
        $web_ips = $this->ec2->getInstanceIPs($web_nodes);
        $db_ips = array('52.32.225.70', '52.25.148.144');
        $conf_content = $this->getConfigurationFile($db_ips);
        $source = tempnam ('/tmp', 'pgpool');
        $destination = '/etc/pgpool-II/pgpool.conf';
        file_put_contents($source, $conf_content);

        foreach($web_ips as $ip) {
            $ip = '52.32.61.254';
            $output = array();
            exec("scp $source $ip:$destination", $output);
            print_r($output);
            exec("ssh $ip \"pgpool -m fast stop ; pgpool -D\"", $output);
            print_r($output);
        }
        unlink($source);
    }
    
    private function assignNodeIds ($unused_node_ids, $unaccounted_servers, &$node_id_mapping){
        foreach($unused_node_ids as $id) {
            $node_id_mapping[$id] = array_pop($unaccounted_servers);
        }
    }

    private function convertToMappingArray($mapping) {
        $mapping_array = array();
        $mapping_array[] = $mapping['master'];
        foreach($mapping['slave'] as $slave) {
            $mapping_array[] = $slave;
        }
        return $mapping_array;
    }

    private function findMaster($db_ips) {
        $master = array();
        foreach ($db_ips as $ip) {
            $result = $this->runQuery($ip);
            if ($result == 'f')  {
                $master[] = $ip;
            }
        }
        if (count($db_ips) == count($master))  {
            return false;
        }
        return $master;
    }

    private function runQuery($ip, $query = 'select pg_is_in_recovery()') {
        $conn = pg_pconnect("host=$ip user=postgres");
        $result = pg_query($conn, $query);
        $row = pg_fetch_row($result);
        return $row[0];
    }

    private function setupReplication($master_ip, $slave_array) {
        $format = 'bash -x /usr/local/bin/followmaster.sh %s %s %s';
        foreach($slave_array as $slave_id => $slave_ip) {
            $command = sprintf($format, $slave_ip, $master_ip, $slave_id);
            $output = array();
            exec($command, $output);
            print_r($output);
        }
    }

    private function exitWithError($message, $exit_code = 1) {
        print_r($message, "\n");
        exit($exit_code);
    }
}
?>
