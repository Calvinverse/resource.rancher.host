# frozen_string_literal: true

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

#
# DOCKER
#

default['docker']['version'] = '19.03.5'

default['docker']['consul_template_network_script_file'] = 'docker_network.ctmpl'
default['docker']['script_network_file'] = '/tmp/docker_network.sh'

#
# ETCD
#

default['etcd']['version'] = '3.3.18'
default['etcd']['url'] = "https://storage.googleapis.com/etcd/#{node['etcd']['version']}/etcd-#{node['etcd']['version']}-linux-amd64.tar.gz"

default['etcd']['path']['install'] = '/usr/local/bin'
default['etcd']['path']['config'] = '/etc/etcd'
default['etcd']['path']['storage_base'] = '/var/lib/etcd'
default['etcd']['path']['data'] = "#{node['etcd']['path']['storage_base']}/data"
default['etcd']['path']['wal'] = "#{node['etcd']['path']['storage_base']}/wal" # Different disk?

default['etcd']['ports']['client'] = 2379
default['etcd']['ports']['peers'] = 2380

default['etcd']['service_user'] = 'etcd'
default['etcd']['service_group'] = 'etcd'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# KUBERNETES
#

default['kubernetes']['ports']['api_server'] = 6443
default['kubernetes']['ports']['kublet'] = 10250
default['kubernetes']['ports']['kube_scheduler'] = 10251
default['kubernetes']['ports']['kube_controller'] = 10252

#
# RANCHER
#
