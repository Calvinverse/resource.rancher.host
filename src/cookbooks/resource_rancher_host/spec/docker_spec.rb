# frozen_string_literal: true

require 'spec_helper'

describe 'resource_rancher_host::docker' do
  context 'configures docker' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs docker' do
      expect(chef_run).to create_docker_installation_package('default').with(
        action: [:create],
        package_name: 'docker-ce',
        package_options: "--force-yes -o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-all'",
        version: '19.03.5'
      )
    end
  end

  context 'set the interface to allow all packets through' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    interface_content = <<~SCRIPT
      # This file describes the network interfaces available on your system
      # and how to activate them. For more information, see interfaces(5).

      source /etc/network/interfaces.d/*

      # The loopback network interface
      auto lo
      iface lo inet loopback

      # The primary network interface
      auto eth0
      iface eth0 inet dhcp
          pre-up sleep 2
          up ifconfig eth0 promisc on
          down ifconfig eth0 promisc off
    SCRIPT
    it 'creates /etc/network/interfaces' do
      expect(chef_run).to create_file('/etc/network/interfaces')
        .with_content(interface_content)
    end
  end
end
