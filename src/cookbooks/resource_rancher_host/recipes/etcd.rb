# frozen_string_literal: true

#
# Cookbook Name:: resource_rancher_host
# Recipe:: etcd
#
# Copyright 2020, P. van der Velde
#

#
# USER
#

# Configure the service user under which etcd will be run
poise_service_user node['etcd']['service_user'] do
  group node['etcd']['service_group']
end

#
# DIRECTORY
#

etcd_config_path = node['etcd']['path']['config']
directory etcd_data_path do
  action :create
  group   node['etcd']['service_group']
  mode '0550'
  owner node['etcd']['service_user']
  recursive true
end

etcd_storage_base_path = node['etcd']['path']['storage_base']
directory etcd_storage_base_path do
  action :create
  group   node['etcd']['service_group']
  mode '0770'
  owner node['etcd']['service_user']
  recursive true
end

etcd_data_path = node['etcd']['path']['data']
directory etcd_data_path do
  action :create
  group   node['etcd']['service_group']
  mode '0770'
  owner node['etcd']['service_user']
  recursive true
end

etcd_wal_path = node['etcd']['path']['wall']
directory etcd_data_path do
  action :create
  group   node['etcd']['service_group']
  mode '0770'
  owner node['etcd']['service_user']
  recursive true
end

#
# FIREWALL
#

etcd_client_port = node['etcd']['ports']['client']
firewall_rule 'etcd-client' do
  command :allow
  description 'Allow Etcd client traffic'
  dest_port etcd_client_port
  direction :in
end

etcd_peers_port = node['etcd']['ports']['peers']
firewall_rule 'etcd-peers' do
  command :allow
  description 'Allow Etcd peer traffic'
  dest_port etcd_peers_port
  direction :in
end

#
# INSTALL
#

tar_extract node['etcd']['url'] do
  action :extract
  creates "#{node['etcd']['path']['install']}/etcd"
  tar_flags [ '-P', '--strip-components 1' ]
  target_dir node['etcd']['path']['install']
end

#
# SERVICE
#

etcd_service = 'etcd'
config_file = "#{etcd_config_path}/conf.yml"
systemd_service etcd_service do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    environment_file '/etc/environment'
    exec_start "#{node['etcd']['path']['install']}/etcd --config-file #{config_file}"
    limit_nofile 65_536
    restart 'always'
    restart_sec 5
  end
  unit do
    after %w[multi-user.target]
    description 'Etcd'
    documentation 'https://github.com/etcd-io/etcd'
    requires %w[multi-user.target]
    start_limit_interval_sec 0
  end
end

#
# CONSUL
#

# Note: ETCD requires a specific host name configuration, otherwise it gets angry
# https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/clustering.md#dns-discovery
etcd_consul_tag = 'rancher'
etcd_consul_service = 'etcd'
file '/etc/consul/conf.d/etcd_service.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "http": "http://localhost:8500/dashboards/consul/ui",
              "id": "etcd_status",
              "interval": "15s",
              "method": "GET",
              "name": "Etcd status",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "etcd",
          "name": "#{etcd_consul_service}",
          "port": #{etcd_peers_port},
          "tags": [
            "#{etcd_consul_tag}",
            "_etcd-server-#{etcd_consul_tag}._tcp"
          ]
        }
      ]
    }
  JSON
end

#
# CONSUL-TEMPLATE
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

# Certs for ETCD

etcd_config_template_file = 'etcd.ctmpl'
file "#{consul_template_template_path}/#{etcd_config_template_file}" do
  action :create
  content <<~CONF
    # Human-readable name for this member.
    name: '{{  }}'

    # Path to the data directory.
    data-dir: #{etcd_data_path}

    # Path to the dedicated wal directory.
    wal-dir: #{etcd_wal_path}

    # Number of committed transactions to trigger a snapshot to disk.
    snapshot-count: 10000

    # Time (in milliseconds) of a heartbeat interval.
    heartbeat-interval: 100

    # Time (in milliseconds) for an election to timeout.
    election-timeout: 1000

    # Raise alarms when backend size exceeds the given quota. 0 means use the
    # default quota.
    quota-backend-bytes: 0

    # List of comma separated URLs to listen on for peer traffic.
    listen-peer-urls: http://0.0.0.0:#{etcd_peers_port}

    # List of comma separated URLs to listen on for client traffic.
    listen-client-urls: http://0.0.0.0:#{etcd_client_port}

    # Maximum number of snapshot files to retain (0 is unlimited).
    max-snapshots: 5

    # Maximum number of wal files to retain (0 is unlimited).
    max-wals: 5

    # Comma-separated white list of origins for CORS (cross-origin resource sharing).
    cors:

    # List of this member's peer URLs to advertise to the rest of the cluster.
    # The URLs needed to be a comma-separated list.
    initial-advertise-peer-urls: http://#{etcd_consul_tag}.#{etcd_consul_service}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:#{etcd_peers_port}

    # List of this member's client URLs to advertise to the public.
    # The URLs needed to be a comma-separated list.
    advertise-client-urls: http://#{etcd_consul_tag}.#{etcd_consul_service}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:#{etcd_client_port}

    # Discovery URL used to bootstrap the cluster.
    discovery:

    # Valid values include 'exit', 'proxy'
    discovery-fallback: 'proxy'

    # HTTP proxy to use for traffic to discovery service.
    discovery-proxy:

    discovery-srv-name: #{etcd_consul_tag}

    # DNS domain used to bootstrap initial cluster.
    discovery-srv: #{etcd_consul_service}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}

    # Initial cluster configuration for bootstrapping.
    initial-cluster: {{ $services := service "#{etcd_consul_tag}.#{etcd_consul_service}|any" }}{{ range $services }}{{ .Address }}:#{etcd_peers_port}{{ end }}

    # Initial cluster token for the etcd cluster during bootstrap.
    initial-cluster-token: 'etcd-{{ keyOrDefault "config/services/consul/datacenter" "unknown" }}'

    # Initial cluster state ('new' or 'existing').
    initial-cluster-state: '{{ if (service "#{etcd_consul_tag}.#{etcd_consul_service}|passing,warning") }}'

    # Reject reconfiguration requests that would cause quorum loss.
    strict-reconfig-check: false

    # Accept etcd V2 client requests
    enable-v2: false

    # Enable runtime profiling data via HTTP server
    enable-pprof: true

    # Valid values include 'on', 'readonly', 'off'
    proxy: 'off'

    # Time (in milliseconds) an endpoint will be held in a failed state.
    proxy-failure-wait: 5000

    # Time (in milliseconds) of the endpoints refresh interval.
    proxy-refresh-interval: 30000

    # Time (in milliseconds) for a dial to timeout.
    proxy-dial-timeout: 1000

    # Time (in milliseconds) for a write to timeout.
    proxy-write-timeout: 5000

    # Time (in milliseconds) for a read to timeout.
    proxy-read-timeout: 0

    client-transport-security:
      # Path to the client server TLS cert file.
      cert-file:

      # Path to the client server TLS key file.
      key-file:

      # Enable client cert authentication.
      client-cert-auth: false

      # Path to the client server TLS trusted CA cert file.
      trusted-ca-file:

      # Client TLS using generated certificates
      auto-tls: false

    peer-transport-security:
      # Path to the peer server TLS cert file.
      cert-file:

      # Path to the peer server TLS key file.
      key-file:

      # Enable peer client cert authentication.
      client-cert-auth: false

      # Path to the peer server TLS trusted CA cert file.
      trusted-ca-file:

      # Peer TLS using generated certificates.
      auto-tls: false

    # Enable debug-level logging for etcd.
    debug: false

    logger: zap

    # Specify 'stdout' or 'stderr' to skip journald logging even when running under systemd.
    log-outputs: [stderr]

    # Force to create a new one member cluster.
    force-new-cluster: false

    auto-compaction-mode: periodic
    auto-compaction-retention: "1"
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

start_etcd_service = '/usr/local/bin/start_etcd.sh'
file start_etcd_service do
  action :create
  content <<~CONF
     #!/bin/bash

    chown #{node['etcd']['service_user']}:#{node['etcd']['service_group']} #{etcd_config_template_file}

    if ( ! $(systemctl is-enabled --quiet #{etcd_service}) ); then
        systemctl enable #{etcd_service}

        while true; do
            if ( $(systemctl is-enabled --quiet #{etcd_service}) ); then
                break
            fi

            sleep 1
        done
    fi

    if ( ! $(systemctl is-active --quiet #{etcd_service}) ); then
        systemctl start #{etcd_service}

        while true; do
            if ( $(systemctl is-active --quiet #{etcd_service}) ); then
                break
            fi

            sleep 1
        done
    fi
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

file "#{consul_template_config_path}/etcd.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{etcd_config_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{etcd_config_template_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "bash #{start_etcd_service}"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "15s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

# TELEGRAF
