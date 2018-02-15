#
# Cookbook:: fail2ban
# Recipe:: default
#
# Copyright:: 2009-2016, Chef Software, Inc.
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

# epel repository is needed for the fail2ban package on rhel
include_recipe 'yum-epel' if platform_family?('rhel')

package 'fail2ban' do
  action :install
  notifies :reload, 'ohai[reload package list]', :immediately
end

ohai 'reload package list' do
  plugin 'packages'
  action :nothing
end

node['fail2ban']['filters'].each do |name, options|
  template "/etc/fail2ban/filter.d/#{name}.conf" do
    source 'filter.conf.erb'
    variables(failregex: [options['failregex']].flatten, ignoreregex: [options['ignoreregex']].flatten)
    notifies :restart, 'service[fail2ban]'
  end
end

template '/etc/fail2ban/fail2ban.conf' do
  source 'fail2ban.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(lazy { { f2b_version: node['packages']['fail2ban']['version'].match(/^[0-9]+\.[0-9]+/)[0].to_f } })
  notifies :restart, 'service[fail2ban]'
end

template '/etc/fail2ban/jail.local' do
  source 'jail.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[fail2ban]'
end

file '/etc/fail2ban/jail.d/defaults-debian.conf' do
  action 'delete'
  only_if { platform?('ubuntu') }
end

service 'fail2ban' do
  supports [status: true, restart: true]
  action [:enable, :start]
  # For Debian fail2ban versions before 0.8.6-3, the status command
  # always returns 0, even when the service isn't running.
  if (platform?('ubuntu') && node['platform_version'].to_f < 12.04) ||
     (platform?('debian') && node['platform_version'].to_f < 7)
    status_command '/etc/init.d/fail2ban status | grep -q "is running"'
  end
end

# Fix the hardcoded 'set logtarget /var/log/fail2ban.log' command that is in
# the stock Debian logrotate config
cookbook_file '/etc/logrotate.d/fail2ban' do
  source 'fail2ban-logrotate.txt'
  owner 'root'
  group 'root'
  mode '0644'
  only_if {
    (platform?('ubuntu') && node['platform_version'].to_f < 16.04) ||
    (platform?('debian') && node['platform_version'].to_f < 9 )
  }
end
