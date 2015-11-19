#
# Cookbook Name:: redis_node
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.


include_recipe 'base'

# Install remi repo
rpm_package "remi_repo" do
    source "http://rpms.famillecollet.com/enterprise/remi-release-6.rpm"
    action :install
end

# Install redis
yum_package 'redis' do
  action :install
  flush_cache [ :before ]
  options '--enablerepo=remi'
end
package 'redis'

# Setup IPtables
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

# Setup redis conf
redis_conf = '/etc/redis.conf'
cookbook_file "#{redis_conf}" do
    source "redis.conf"
    owner "redis"
    group "root"
    mode 0644
    notifies :restart, 'service[redis]', :immediately
    only_if { ::File.exists?("#{redis_conf}") }
end

service 'redis' do
    action :start
end
