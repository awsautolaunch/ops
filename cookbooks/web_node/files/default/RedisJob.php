<?php

namespace AppBundle\App;
require_once '/var/www/html/current/symfony/src/AppBundle/App/lib/Ec2Client.php';

Class RedisJob{

    private $ec2;
    public function runJob($job_file) {
        $this->ec2 = new Ec2Client('us-west-2','latest');
        $working_nodes = $this->getWorkingNodes('cloudinit');
        $running_nodes = $this->ec2->getInstanceIDs('redis_node');
    
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

    private function getWorkingNodes($tag_name, $role_name="redis_node") {
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
    

    private function pushConfig($instanceIds) {
        $redis_ips = $this->ec2->getInstanceIPs($instanceIds);
        $web_nodes = $this->getWorkingNodes('cloudinit','web_node');
        $web_ips = $this->ec2->getInstanceIPs($web_nodes);
        $source = tempnam ('/tmp', 'redis.ips');
        $destination = '/var/www/html/configs/redis.ips';     
        file_put_contents($source, json_encode($redis_ips));
        foreach($web_ips as $ip) {
            $ip = '52.32.61.254';
            exec("scp $source $ip:$destination");
        }
        unlink($source);
    }
}
?>
