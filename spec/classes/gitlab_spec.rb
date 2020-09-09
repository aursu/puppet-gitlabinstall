# frozen_string_literal: true

require 'spec_helper'

describe 'gitlabinstall::gitlab' do
  let(:pre_condition) do
    <<-PRECOND
    class { 'gitlabinstall': external_url => 'https://ci.domain.tld' }
    tlsinfo::certificate { 'f1453246': }
    PRECOND
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(stype: 'gitlab') }
      let(:params) do
        {
          database_password: 'MySecretPassword',
        }
      end

      it { is_expected.to compile }
    end
  end
end
