# frozen_string_literal: true

require 'spec_helper'

describe 'gitlabinstall::runner::service' do
  let(:pre_condition) do
    <<-PRECOND
    include dockerinstall
    include dockerinstall::compose
    PRECOND
  end
  let(:title) { 'namevar' }
  let(:params) do
    {}
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
          .with_configuration(%r{^[ ]{4}image: gitlab/gitlab-runner:v15\.10\.1$})
      }

      it {
        is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
          .without_configuration(%r{extra_hosts})
      }

      it {
        is_expected.to contain_file('/srv/gitlab-runner/namevar')
          .with_ensure('directory')
      }

      it {
        is_expected.to contain_file('/srv/gitlab-runner/namevar/config')
          .with_ensure('directory')
          .that_comes_before('Dockerinstall::Composeservice[gitlab/namevar]')
      }

      it {
        is_expected.not_to contain_dockerimage('gitlab/gitlab-runner:v14.0.1')
      }

      context 'check environment setup' do
        let(:params) do
          {
            docker_host: 'docker.domain.tld',
          }
        end

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}DOCKER_TLS_CERTDIR: /certs$})
        }

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}DOCKER_CERT_PATH: /certs/client$})
        }

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}DOCKER_TLS_VERIFY: 1$})
        }

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}DOCKER_HOST: tcp://docker.domain.tld:2376$})
        }
      end

      context 'check docker volumes' do
        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}- /etc/docker/certs.d:/etc/docker/certs.d$})
        }

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}- /var/run/docker.sock:/var/run/docker.sock$})
        }

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}- /etc/docker/tls:/certs/client$})
        }

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}- /srv/gitlab-runner/namevar/config:/etc/gitlab-runner$})
        }
      end

      context 'check extra hosts setup' do
        let(:params) do
          {
            docker_host: 'docker.domain.tld',
            docker_ipaddr: '192.168.178.200',
          }
        end

        it {
          is_expected.to contain_dockerinstall__composeservice('gitlab/namevar')
            .with_configuration(%r{^[ ]{6}- docker.domain.tld:192.168.178.200$})
        }
      end
    end
  end
end
