# frozen_string_literal: true

#
# Cookbook Name:: resource_rancher_host
# Recipe:: default
#
# Copyright 2019, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_rancher_host::firewall'

include_recipe 'resource_rancher_host::docker'
include_recipe 'resource_rancher_host::meta'
include_recipe 'resource_rancher_host::nomad'
include_recipe 'resource_rancher_host::provisioning'
