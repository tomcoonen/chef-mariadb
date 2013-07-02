#
# Cookbook Name:: mariadb
# Recipe:: default
#
# Copyright 2008-2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

include_recipe "mariadb::mariadb_repo"
include_recipe "mariadb::client"

if Chef::Config[:solo]
  missing_attrs = %w{
    server_debian_password server_root_password server_repl_password
  }.select do |attr|
    node["mariadb"][attr].nil?
  end.map { |attr| "node['mariadb']['#{attr}']" }

  if !missing_attrs.empty?
    Chef::Application.fatal!([
        "You must set #{missing_attrs.join(', ')} in chef-solo mode.",
        "For more information, see https://github.com/opscode-cookbooks/mysql#chef-solo-note"
      ].join(' '))
  end
else
  # generate all passwords
  node.set_unless['mariadb']['server_debian_password'] = secure_password
  node.set_unless['mariadb']['server_root_password']   = secure_password
  node.set_unless['mariadb']['server_repl_password']   = secure_password
  node.save
end

unless node['mariadb']['replication']['master'].nil? and node['mariadb']['replication']['slave'].nil?
  missing_attrs = %w{user}.select do |attr|
    node['mariadb']['replication'][attr].nil?
  end.map { |attr| "node['mariadb']['replication']" }

  unless missing_attrs.empty?
    Chef::Application.fatal!("You must set for the replication")
  end

  if node['mariadb']['replication']['secret'].nil?
    node.default['mariadb']['replication']['secret'] = node['mariadb']['server_repl_password']
  end

  if node['mariadb']['tunable']['server_id'].nil?
    node.default['mariadb']['tunable']['log_bin'] = node["hostname"] if node['mariadb']['tunable']['log_bin'].nil?
    node.default['mariadb']['tunable']['binlog_format'] = "MIXED"
    node.default['mariadb']['tunable']['server_id'] = (node['macaddress'].gsub(/:/, "").to_i(16) % (2**32 - 1)).to_s(10)
  end
end

if platform_family?(%w{debian})

  directory "/var/cache/local/preseeding" do
    owner "root"
    group node['mariadb']['root_group']
    mode 0755
    recursive true
  end

  execute "preseed mysql-server" do
    command "debconf-set-selections /var/cache/local/preseeding/mysql-server.seed"
    action :nothing
  end

  template "/var/cache/local/preseeding/mysql-server.seed" do
    source "mysql-server.seed.erb"
    owner "root"
    group node['mariadb']['root_group']
    mode "0600"
    notifies :run, "execute[preseed mysql-server]", :immediately
  end

  template "#{node['mariadb']['conf_dir']}/debian.cnf" do
    source "debian.cnf.erb"
    owner "root"
    group node['mariadb']['root_group']
    mode "0600"
  end

end

if platform_family?('windows')
  package_file = node['mariadb']['package_file']

  remote_file "#{Chef::Config[:file_cache_path]}/#{package_file}" do
    source node['mariadb']['url']
    not_if { File.exists? "#{Chef::Config[:file_cache_path]}/#{package_file}" }
  end

  windows_package node['mariadb']['server']['packages'].first do
    source "#{Chef::Config[:file_cache_path]}/#{package_file}"
  end

  def package(*args, &blk)
    windows_package(*args, &blk)
  end
end

node['mariadb']['server']['packages'].each do |package_name|
  package package_name do
    action :install
  end
end

unless platform_family?(%w{mac_os_x})

  [File.dirname(node['mariadb']['pid_file']),
    File.dirname(node['mariadb']['tunable']['slow_query_log']),
    node['mariadb']['conf_dir'],
    node['mariadb']['confd_dir'],
    node['mariadb']['log_dir'],
    node['mariadb']['data_dir']].each do |directory_path|
    directory directory_path do
      owner "mysql" unless platform? 'windows'
      group "mysql" unless platform? 'windows'
      action :create
      recursive true
    end
  end

  if platform_family? 'windows'
    require 'win32/service'

    windows_path node['mariadb']['bin_dir'] do
      action :add
    end

    windows_batch "install mysql service" do
      command "\"#{node['mariadb']['bin_dir']}\\mysqld.exe\" --install #{node['mariadb']['service_name']}"
      not_if { Win32::Service.exists?(node['mariadb']['service_name']) }
    end
  end

  skip_federated = case node['platform']
                   when 'fedora', 'ubuntu', 'amazon'
                     true
                   when 'centos', 'redhat', 'scientific'
                     node['platform_version'].to_f < 6.0
                   else
                     false
                   end
end

# Homebrew has its own way to do databases
if platform_family?(%w{mac_os_x})
  execute "mysql-install-db" do
    command "mysql_install_db --verbose --user=`whoami` --basedir=\"$(brew --prefix mysql)\" --datadir=#{node['mariadb']['data_dir']} --tmpdir=/tmp"
    environment('TMPDIR' => nil)
    action :run
    creates "#{node['mariadb']['data_dir']}/mysql"
  end
else
  template "#{node['mariadb']['conf_dir']}/my.cnf.d/server.cnf" do
    source "my.cnf.erb"
    owner "root" unless platform? 'windows'
    group node['mariadb']['root_group'] unless platform? 'windows'
    mode "0644"

    case node['mariadb']['reload_action']
    when 'restart'
      notifies :restart, "service[mysql]", :immediately
    when 'reload'
      notifies :reload, "service[mysql]", :immediately
    else
      Chef::Log.info "my.cnf updated but mysql.reload_action is #{node['mariadb']['reload_action']}. No action taken."
    end

    variables :skip_federated => skip_federated
  end

  execute 'mysql-install-db' do
    command "mysql_install_db"
    action :run
    not_if { File.exists?(node['mariadb']['data_dir'] + '/mysql/user.frm') }
  end

  service "mysql" do
    service_name node['mariadb']['service_name']
    if node['mariadb']['use_upstart']
      provider Chef::Provider::Service::Upstart
    end
    supports :status => true, :restart => true, :reload => true
    action :enable
  end

  service "mysql" do
    action :start
  end
end

unless platform_family?(%w{mac_os_x})
  grants_path = node['mariadb']['grants_path']

  begin
    t = resources("template[#{grants_path}]")
  rescue
    Chef::Log.info("Could not find previously defined grants.sql resource")
    t = template grants_path do
      source "grants.sql.erb"
      owner "root" unless platform_family? 'windows'
      group node['mariadb']['root_group'] unless platform_family? 'windows'
      mode "0600"
      action :create
    end
  end

  if platform_family? 'windows'
    windows_batch "mysql-install-privileges" do
      command "\"#{node['mariadb']['mariadb_bin']}\" < \"#{grants_path}\""
      action :nothing
      subscribes :run, resources("template[#{grants_path}]"), :immediately
    end
  else
    execute "mysql-install-privileges" do
      command %Q["#{node['mariadb']['mariadb_bin']}" < "#{grants_path}"]
      action :nothing
      subscribes :run, resources("template[#{grants_path}]"), :immediately
    end
  end

  service "mysql" do
    action :start
  end
end

# set the root password for situations that don't support pre-seeding.
# (eg. platforms other than debian/ubuntu & drop-in mysql replacements)
execute "assign-root-password" do
  command "\"#{node['mariadb']['mariadbadmin_bin']}\" -u root password \"#{node['mariadb']['server_root_password']}\""
  action :run
  only_if "\"#{node['mariadb']['mariadb_bin']}\" -u root -e 'show databases;'"
end

if node['mariadb']['replication']['master'] == true
  template "#{node['mariadb']['data_dir']}/replication_master_script" do
    source "replication_master_script.erb"
    owner "root" unless platform? 'windows'
    group node['mariadb']['root_group'] unless platform? 'windows'
    mode "0600"
  end
end

if node['mariadb']['replication']['slave'] == true
  template "#{node['mariadb']['data_dir']}/replication_slave_script" do
    source "replication_slave_script.erb"
    owner "root" unless platform? 'windows'
    group node['mariadb']['root_group'] unless platform? 'windows'
    mode "0600"
  end
end

