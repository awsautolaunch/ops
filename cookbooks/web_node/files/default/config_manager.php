<?php
namespace AppBundle\App;

$jobs_dir = "/var/www/html/jobs/";
$lock_file = $jobs_dir . ".running";

# Includes.
foreach(glob('lib/' . '*.php') as $filename) {
    require $filename;
}

function getJobs () {
    global $jobs_dir;
    $exclude_list = array(".", "..", ".running");
    return array_diff(scandir($jobs_dir), $exclude_list);
}

function dispatchJobs($jobs) {
    global $jobs_dir;
    foreach ($jobs as $job) {
        $file_path = $jobs_dir . $job;
        $job_info = json_decode(file_get_contents($file_path), true);
        $job_name = $job_info['job_name'];
        print_r($job_name);
        print_r("\n");
        switch ($job_name) {
            case "redis_node":
                $redis_job = new RedisJob();
                $redis_job->runJob($file_path);
                break;
            case "db_node":
                $db_job = new DbJob();
                $db_job->runJob($file_path);
                break;
        }
    }
}

$jobs = getJobs();
dispatchJobs($jobs);



?>
