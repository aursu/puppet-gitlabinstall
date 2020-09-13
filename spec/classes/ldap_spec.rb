# frozen_string_literal: true

require 'spec_helper'

describe 'gitlabinstall::ldap' do
  let(:pre_condition) { 'include gitlabinstall' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          host: 'ldap.mydomain.com',
          password: 'secret',
          base: 'ou=people,dc=gitlab,dc=example',
        }
      end

      it { is_expected.to compile }
    end
  end
end
