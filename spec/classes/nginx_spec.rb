# frozen_string_literal: true

require 'spec_helper'

describe 'gitlabinstall::nginx' do
  let(:pre_condition) do
    <<-PRECOND
    class { 'gitlabinstall': external_url => 'https://ci.domain.tld' }
    PRECOND
  end

  on_supported_os.each do |os, os_facts|
    os_facts[:os]['selinux'] = { 'enabled' => true }

    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_nginx__resource__server('gitlab-http')
          .with_server_name(['ci.domain.tld'])
      }

      it {
        is_expected.to contain_nginx__resource__location('/')
          .with_server('gitlab-http')
      }

      it {
        is_expected.to contain_nginx__resource__location('/assets')
          .with_server('gitlab-http')
      }

      context 'with relative URL set' do
        let(:pre_condition) do
          <<-PRECOND
          class { 'gitlabinstall': external_url => 'https://ci.domain.tld/gitlab' }
          PRECOND
        end

        it {
          is_expected.to contain_nginx__resource__location('/gitlab')
            .with_server('gitlab-http')
        }

        it {
          is_expected.to contain_nginx__resource__location('/gitlab/assets')
            .with_server('gitlab-http')
        }

        context 'with monitoring whitelist' do
          let(:params) do
            {
              monitoring_whitelist: ['127.0.0.0/8'],
            }
          end

          it {
            is_expected.to contain_nginx__resource__location('= /gitlab/-/health')
              .with_server('gitlab-http')
          }
        end
      end
    end
  end
end
