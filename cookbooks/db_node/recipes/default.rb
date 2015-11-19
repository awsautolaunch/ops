#
# Cookbook Name:: db_node
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# Include Base cookbook
include_recipe 'base'

# Allow DB traffic
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
    source "http://yum.postgresql.org/9.2/redhat/rhel-6-x86_64/pgdg-centos92-9.2-7.noarch.rpm"
    action :install
end

# Install postgresql
package 'postgresql92-server' do
    action :install
    notifies :run, 'execute[init_db]', :immediately
end

# DB Init
execute 'init_db' do
    command 'service postgresql-9.2 initdb'
    action :nothing
end

# Setup config files.
db_dir = "/var/lib/pgsql/9.2/data"
cookbook_file "#{db_dir}/site.sql" do
    source "site.sql"
    owner "postgres"
    group "postgres"
    mode 0700
    not_if { ::File.exists?("#{db_dir}/site.sql.done") }
end

cookbook_file "#{db_dir}/postgresql.conf" do
    source "postgresql.conf"
    owner "postgres"
    group "postgres"
    mode 0700
end

cookbook_file "#{db_dir}/pg_hba.conf" do
    source "pg_hba.conf"
    owner "postgres"
    group "postgres"
    mode 0700
end


# Service postgresql
service "postgresql-9.2" do
    action :start
end

# Create DB schema
bash 'import_schema' do
    code <<-EOH
        sleep 3
        psql -U postgres -f #{db_dir}/site.sql
        mv #{db_dir}/site.sql #{db_dir}/site.sql.done
    EOH
    not_if { ::File.exists?("#{db_dir}/site.sql.done") }
    action :run
end
