#
# Cookbook Name:: base
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# Install minimum required packages.

ssh_dir = "/root/.ssh"
package ['epel-release', 'vim', 'wget', 'nc', 'telnet', 'htop', 'man', 'ntp']

# Push ssh priv key.
directory "#{ssh_dir}" do
  owner 'root'
  group 'root'
  mode '0700'
  action :create
end

execute 'ssh_selinx' do
  command "/sbin/restorecon -r #{ssh_dir}"
  action :nothing
end

cookbook_file "#{ssh_dir}/id_rsa" do
    source 'id_rsa'
    mode '0600'
end

cookbook_file "#{ssh_dir}/config" do
    source 'ssh_config'
    mode '0600'
    notifies :run, 'execute[ssh_selinx]', :immediately
end

cookbook_file "#{ssh_dir}/authorized_keys" do
    source 'id_rsa.pub'
    mode '0600'
    notifies :run, 'execute[ssh_selinx]', :immediately
end

# Tag script
tag_script_file="/opt/ops/chef/tag.sh"
cookbook_file "#{tag_script_file}" do
    source 'tag.sh'
    mode '0744'
    notifies :run, 'bash[tag_server]', :immediately
end

bash 'tag_server' do
    code <<-EOH
        bash #{tag_script_file} group_name $(cat /opt/ops/chef/run_list)
    EOH
    action :nothing
    notifies :run, 'execute[cloudinit_complete]', :delayed
end

# Add pull script to run chef-client.
pull_script_file="/opt/ops/chef/pull_script.sh"
cookbook_file "#{pull_script_file}" do
    source 'pull_script.sh'
    mode '0744'
end

cron 'pull_script.sh' do
    minute '*/30'
    command "bash #{pull_script_file}"
end

# Cloud Init Complete
execute 'cloudinit_complete' do
    command 'bash /opt/ops/chef/tag.sh cloudinit true'
    action :nothing
end
