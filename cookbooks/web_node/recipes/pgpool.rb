#
# Cookbook Name:: web_node
# Recipe:: pgpool
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# Download pgpool RPM>
remote_file "#{Chef::Config[:file_cache_path]}/pgpool_3.4.rpm" do
    source "http://www.pgpool.net/yum/rpms/3.4/redhat/rhel-6-x86_64/pgpool-II-pg92-3.4.0-2pgdg.rhel6.x86_64.rpm"
    notifies :install, "yum_package[install_pgpool]", :immediately
end

# Install pgpool rpm
yum_package "install_pgpool" do
    source "#{Chef::Config[:file_cache_path]}/pgpool_3.4.rpm"
    only_if {::File.exists?("#{Chef::Config[:file_cache_path]}/pgpool_3.4.rpm")}
    action :nothing
    notifies :run, 'execute[disable_pgpool_config]', :immediately

end

pgpool_dir = "/etc/pgpool-II"

# Rename default conf.
execute 'disable_pgpool_config' do
    command "mv #{pgpool_dir}/pgpool.conf #{pgpool_dir}/pgpool.conf.default"
    action :nothing
    only_if { ::File.exists?("#{pgpool_dir}/pgpool.conf") }
end


# Setup pgpool config files.

directory '/var/run/pgpool/' do
    action :create
end

cookbook_file "#{pgpool_dir}/pcp.conf" do
    source "pcp.conf"
    owner "root"
    group "root"
    mode 0644
end
cookbook_file "#{pgpool_dir}/pgpool.conf" do
    source "pgpool.conf.tmpl"
    owner "root"
    group "root"
    mode 0644
    not_if { ::File.exists?("#{pgpool_dir}/pgpool.conf") }
end
cookbook_file "#{pgpool_dir}/pgpool.conf.tmpl" do
    source "pgpool.conf.tmpl"
    owner "root"
    group "root"
    mode 0644
end
cookbook_file "#{pgpool_dir}/pool_hba.conf" do
    source "pool_hba.conf"
    owner "root"
    group "root"
    mode 0644
end
cookbook_file "#{pgpool_dir}/pool_passwd" do
    source "pg_pool_passwd"
    owner "root"
    group "root"
    mode 0644
end
execute "start_pgpool" do
    cwd "#{pgpool_dir}"
    command "pgpool -D"
    not_if { ::File.exists?("/var/run/pgpool/pgpool.pid") }
end

# Failover scripts.
cookbook_file "/usr/local/bin/failover.sh" do
    source "failover.sh"
    owner "root"
    group "root"
    mode 0755
end

cookbook_file "/usr/local/bin/followmaster.sh" do
    source "followmaster.sh"
    owner "root"
    group "root"
    mode 0755
end
