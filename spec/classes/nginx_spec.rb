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

      context 'with manage_nginx_core => false' do
        let(:pre_condition) do
          <<-PRECOND
          include nginx
          class { 'gitlabinstall': external_url => 'https://ci.domain.tld' }
          PRECOND
        end
        let(:params) do
          {
            manage_service: false,
          }
        end

        it {
          is_expected.to contain_nginx__resource__config('98-gitlab-global-proxy')
            .with_content(%r{proxy_cache gitlab})
        }

        it {
          is_expected.to contain_nginx__resource__config('98-gitlab-global-proxy')
            .with_content(%r{proxy_cache_path /var/cache/nginx/proxy_cache keys_zone=gitlab:10m max_size=1g levels=1:2 use_temp_path=off})
        }
      end
    end
  end
end
