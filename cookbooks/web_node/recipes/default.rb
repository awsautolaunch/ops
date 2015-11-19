#
# Cookbook Name:: web_node
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.


# Base cookbook
include_recipe 'base'
include_recipe 'web_node::pgpool'

# Allow http traffic
cookbook_file "/etc/sysconfig/iptables" do
    source "iptables"
    owner "root"
    group "root"
    mode 0600
    notifies :restart, 'service[iptables]', :immediately
end

service 'iptables' do
    action :nothing
end


# Add PHP 5.4 repo
rpm_package "add_php_repo" do
    source "https://mirror.webtatic.com/yum/el6/latest.rpm"
    action :install
end

# Install PHP packages
package ['php55w', 'php55w-mbstring', 'php55w-xml', 'php55w-process', 'php55w-intl', 'php55w-pgsql', 'php55w-pecl-zendopcache' ]

# Install webserver related packages
package ['php55w-fpm', 'nginx', 'git']

# Install symfony
bash 'install_symfony' do
    code <<-EOH
        curl -LsS http://symfony.com/installer -o /usr/local/bin/symfony
        chmod a+x /usr/local/bin/symfony
        mkdir -p /opt/ops/config_manager/lib
    EOH
    not_if { ::File.exists?('/usr/local/bin/symfony') }
end

# Install composer
bash 'install_composer' do
    cwd '/tmp'
    code <<-EOH
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
    EOH
    not_if { ::File.exists?('/usr/local/bin/composer') }
end

# Configure nginx
execute 'disable_nginx_default_config' do
    command 'mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak'
    only_if { ::File.exists?('/etc/nginx/conf.d/default.conf') }
end

cookbook_file '/etc/nginx/nginx.conf' do
    source 'nginx_conf.conf'
end

cookbook_file '/etc/nginx/conf.d/endpoint.conf' do
    source 'nginx_endpoint.conf'
end

# Configure php-fpm
cookbook_file '/etc/php-fpm.d/www.conf' do
    source 'php_fpm_www.conf'
    #notifies :create, 'cookbook_file[/tmp/php_fpm_postgres.pp]', :immediately
end

# Install SELinux module to allow php-fpm to connect to postgres socket.
#cookbook_file "/tmp/php_fpm_postgres.pp" do
#    source "php_fpm_postgres.pp"
#    mode 0755
    #notifies :run, 'bash[php_fpm_selinux]', :immediately
#    action :nothing
#end

#bash 'php_fpm_selinux' do
#    code <<-EOH
#        semodule -i /tmp/php_fpm_postgres.pp
#        setsebool -P httpd_can_network_connect on
#        sysctl -w net.core.somaxconn=1024
#        ulimit -n 16384
#    EOH
#    action :nothing
#end

# Code push
deploy_revision 'endpoint_repo' do
    repo 'git@github.com:ttassignment/assignment.git'
    migrate false
    symlink_before_migrate.clear
    create_dirs_before_symlink.clear
    purge_before_symlink.clear
    symlinks.clear
    revision "master"
    deploy_to '/var/www/html'
    action :deploy
    notifies :restart, 'service[php-fpm]'
    notifies :restart, 'service[nginx]'
    notifies :run, 'execute[release_folder_perms]'
end

cookbook_file "/opt/ops/config_manager/lib//DbJob.php" do
    source "/DbJob.php"
    owner "root"
    group "root"
    mode 0755
end

cookbook_file "/opt/ops/config_manager/lib/RedisJob.php" do
    source "RedisJob.php"
    owner "root"
    group "root"
    mode 0755
end

cookbook_file "/opt/ops/config_manager/config_manager.php" do
    source "config_manager.php"
    owner "root"
    group "root"
    mode 0755
end

cookbook_file "/opt/ops/config_manager/config_manager.sh" do
    source "config_manager.sh"
    owner "root"
    group "root"
    mode 0755
end

cron 'config_manager.sh' do
    minute '*'
    command "bash /opt/ops/config_manager/config_manager.sh"
end

bash "config_manager_first_time" do
    code <<-EOH
        mkdir -p /var/www/html/configs /var/www/html/jobs
        echo '{"job_name":"db_node"}' > /var/www/html/jobs/first_db_job
        echo '{"job_name":"redis_node"}' > /var/www/html/jobs/first_redis_job
        chown nginx.nginx -R /var/www/html/configs /var/www/html/jobs
    EOH
    not_if { ::File.exists?('/var/www/html/jobs') }
end

cookbook_file "/etc/php.ini" do
    source "php.ini"
    owner "root"
    group "root"
    mode 0644
    notifies :restart, 'service[php-fpm]', :immediately
end

# Set file perms
execute "release_folder_perms" do
    command 'chown -R nginx.nginx /var/www/html/releases/'
    action :nothing
end

# Start webservices.
service "php-fpm" do
    action :nothing
end

service "nginx" do
    action :nothing
end
