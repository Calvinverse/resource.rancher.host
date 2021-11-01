# frozen_string_literal: true

#
# Cookbook Name:: resource_rancher_host
# Recipe:: docker
#
# Copyright 2020, P. van der Velde
#

include_recipe 'chef-apt-docker::default'

directory '/etc/docker' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

docker_data_path = '/srv/containers/docker'
directory docker_data_path do
  action :create
  mode '777'
  recursive true
end

# Make docker run in experimental mode so that we have the macvlan network driver
file '/etc/docker/daemon.json' do
  action :create
  content <<~JSON
    {
        "experimental": true,
        "graph": "#{docker_data_path}"
    }
  JSON
end

# Install the latest version of docker
docker_installation_package 'default' do
  action :create
  package_name 'docker-ce'
  package_options "--force-yes -o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-all'"
  version node['docker']['version']
end

#
# UPDATE THE NETWORK INTERFACE
#

# Turn on promiscuous mode so that all packets for all MAC addresses are processed, including
# the ones for the docker containers
file '/etc/network/interfaces' do
  action :create
  content <<~SCRIPT
    # This file describes the network interfaces available on your system
    # and how to activate them. For more information, see interfaces(5).

    source /etc/network/interfaces.d/*

    # The loopback network interface
    auto lo
    iface lo inet loopback

    # The primary network interface
    auto eth0
    iface eth0 inet dhcp

    # The secundary network interface. This one is used by docker
    auto eth1
    iface eth1 inet dhcp
        pre-up sleep 2
        up ifconfig eth1 promisc on
        down ifconfig eth1 promisc off
  SCRIPT
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

docker_network_script_template_file = node['docker']['consul_template_network_script_file']
file "#{consul_template_template_path}/#{docker_network_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ $hostname := (file "/etc/hostname" | trimSpace ) }}
    {{ if keyExists (printf "config/services/jobs/containers/%s/network/initialized" $hostname) }}

    echo 'Write the docker daemon file'
    cat <<EOT > /etc/docker/daemon.json
    {
        "experimental": true,
        "graph": "#{docker_data_path}",
        "insecure-registries": [
          {{ keyOrDefault "config/services/jobs/containers/registries/insecure" "" }}
        ],
        "registry-mirrors" : [
          {{ keyOrDefault "config/services/jobs/containers/registries/mirror" "" }}
        ]
    }
    EOT

    echo 'Wrote docker daemon file. Restarting docker'
    sudo systemctl restart docker.service

    HOST_IP={{ key (printf "config/services/jobs/containers/hosts/%s/network/hostip" $hostname) }}








    # SET THE IP ADDRESS OF THE SECOND NETWORK INTERFACE ON THE HOST








    ADDRESS_SPACE={{ key (printf "config/services/jobs/containers/hosts/%s/network/subnet" $hostname) }}
    IPRANGE={{ key (printf "config/services/jobs/containers/hosts/%s/network/iprange" $hostname) }}
    GATEWAY={{ key (printf "config/services/jobs/containers/hosts/%s/network/gateway" $hostname) }}
    VLANTAG={{ key (printf "config/services/jobs/containers/hosts/%s/network/vlan" $hostname) }}
    if [[ $VLANTAG != '' && $VLANTAG != .* ]]; then
      VLANTAG=".${VLANTAG}"
    fi

    echo 'Configuring macvlan network on eth1 ...'
    docker network create -d macvlan --subnet=$ADDRESS_SPACE --ip-range=$IPRANGE --gateway=$GATEWAY -o parent=eth1${VLANTAG} docker_macvlan

    {{ else }}
    echo 'Not all Consul K-V values are available. Will not update the docker network information.'
    {{ end }}
  CONF
  mode '755'
end

docker_network_script_file = node['docker']['script_network_file']
file "#{consul_template_config_path}/nomad_region.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{docker_network_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{docker_network_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{docker_network_script_file}"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "60s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0755

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  mode '755'
end
