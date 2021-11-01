# frozen_string_literal: true

require 'spec_helper'

describe 'resource_rancher_host::etcd' do
  context 'configures docker' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
  end
end