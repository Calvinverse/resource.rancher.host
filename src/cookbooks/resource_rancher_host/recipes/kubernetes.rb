# frozen_string_literal: true

#
# Cookbook Name:: resource_rancher_host
# Recipe:: kubernetes
#
# Copyright 2020, P. van der Velde
#

#
# TURN OFF SWAP
#

# https://askubuntu.com/a/984777
# swapoff -a
execute 'turn off immediately' do
  action :run
  command "sudo swapoff -a"
end

# edit /etc/fstab and comment any swap entries if present: "sudo "
execute 'turn off swap permanently' do
  action :run
  command "sudo sed -i '/ swap / s/^\\(.*\\)$/#\\1/g' /etc/fstab"
end

# run: sudo systemctl mask dev-sdXX.swap (where XX is the swap partition.
#   Also useful to do it for all possible partitions so that if there is a swap
#   partition on any other drive it will not be mounted)
systemd_unit 'dev-mapper-system\x2dswap_1.swap' do
  action :mask
end


#
# INSTALL PACKAGES
#

%w[apt-transport-https curl].each do |pkg|
  apt_package pkg do
    action :install
  end
end

#
# INSTALL KUBERNETES
#

apt_repository 'kubernetes-apt-repository' do
  action :add
  components %w[main]
  distribution 'stable'
  key 'https://packages.cloud.google.com/apt/doc/apt-key.gpg'
  uri 'https://apt.kubernetes.io/'
end

%w[kubelet kubeadm kubectl].each do |pkg|
  apt_package pkg do
    action :install
  end
end

service 'kubelet' do
  action :disable
end

#
# FIREWALL
#

kubernetes_api_server_port = node['kubernetes']['ports']['api_server']
firewall_rule 'kubernetes-api-server' do
  command :allow
  description 'Allow Kubernetes API server'
  dest_port kubernetes_api_server_port
  direction :in
end

kubernetes_kublet_port = node['kubernetes']['ports']['kublet']
firewall_rule 'kubernetes-kublet' do
  command :allow
  description 'Allow Kubernetes kublet API'
  dest_port kubernetes_kublet_port
  direction :in
end

kubernetes_kube_scheduler_port = node['kubernetes']['ports']['kube_scheduler']
firewall_rule 'kubernetes-kube-scheduler' do
  command :allow
  description 'Allow Kubernetes kube-scheduler'
  dest_port kubernetes_kube_scheduler_port
  direction :in
end

kubernetes_kube_controller_port = node['kubernetes']['ports']['kube_controller']
firewall_rule 'kubernetes-kube-controller' do
  command :allow
  description 'Allow Kubernetes kube-controller'
  dest_port kubernetes_kube_controller_port
  direction :in
end

#
# SERVICE
#

# kubelet is the service
