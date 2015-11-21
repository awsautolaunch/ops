<?php

    namespace AppBundle\App;

    define("__ROOT__", __DIR__);
    require __ROOT__ . '/../../symfony/src/AppBundle/App/lib/Ec2Client.php';

    $config_dir = __ROOT__ . "/../config/";
    $web_config;

    $ec2 = new Ec2Client('us-west-2','latest');

    function getINIConfig ($config_name) {
        $config = parse_ini_file($config_name, true); 
        return $config;
    }

    function healthCheck($health_check_url) {
        $health_check = curl($health_check_url);
        if ($health_check === false) {
            return false;
        }
    }

    function curl ($url, $expected_code = 200, $post_data = false) {
        $curl = curl_init();
        curl_setopt ($curl, CURLOPT_URL, $url);
        curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
        if ($post_data) {
            curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "POST");
            curl_setopt($curl, CURLOPT_POSTFIELDS, $post_data);
            curl_setopt($curl, CURLOPT_HTTPHEADER, array(
                'Content-Type: application/json',
                'Content-Length: ' . strlen($post_data))
            );
        } 
        $result = curl_exec ($curl);
        $httpcode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close ($curl);
        if ($httpcode != $expected_code)  {
            print_r($result);
            return false;
        }
        return $result;
    }
    
    function getUserData($configs) {
        if ((array_key_exists('user_data_template', $configs['common']) === false) || (array_key_exists('role_name', $configs['chef']) === false)) {
            return false;
        }
        $chef_role = $configs['chef']['role_name'];
        $template_file = $configs['common']['user_data_template'];

        $user_data = file_get_contents(__ROOT__ . '/' . $template_file);
        $user_data = str_replace('CHEF_ROLE_PLACE_HOLDER', $chef_role, $user_data);
        return base64_encode($user_data);
    }

    function checkIfSetupEndpointIsAvailable ($web_config) {
        $health_check = healthCheck($web_config['common']['health_check']);
        if ($health_check === false) {
            return false;
        }
        return true;
    }

    function hitSetupAPI() {
        global $config_dir, $web_config;
        $config_array = array();
        foreach (glob($config_dir . "*.ini") as $filename) {
            $config_array[] = getConfigs($filename);
        }
        $post_data = json_encode($config_array);
        $url = $web_config['common']['setup_endpoint'];
        $status = curl($url, 200, $post_data);
        print_r($status);
    }

    function getConfigs ($file_name) {
        $config = getINIConfig($file_name);
        $user_data = getUserData($config);
        if ($user_data !== false) {
            $config['aws']['UserData'] = $user_data;
        }
        return $config;
    }

    function exitOnError($message, $exit_code) {
        print_r($message);
        echo "\n";
        exit($exit_code);
    }

    function main () {
        global $ec2, $config_dir, $web_config;
        $web_config = getINIConfig($config_dir . 'web_node.ini');

        if (checkIfSetupEndpointIsAvailable($web_config) === true) {
            hitSetupAPI();
        } else {
            if ($web_config['common']['enabled'] == false) {
                exitOnError('web_pool is disabled. Need atleast 1 web_node to continue. Set enabled = true in web_pool.ini', 1);
            }
            
            $aws_settings = $web_config["aws"];
            $result = $ec2->updateAutoScalingGroup($aws_settings);
            while (checkIfSetupEndpointIsAvailable($web_config) === false) {
                print_r("Waiting 30 secs, for web server to boot...\n");
                sleep(30);
            }
            hitSetupAPI();
        }
    }


    main();
?>

