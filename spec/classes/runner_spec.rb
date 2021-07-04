# frozen_string_literal: true

require 'spec_helper'

describe 'gitlabinstall::runner' do
  let(:pre_condition) do
    <<-PRECOND
    include dockerinstall
    include dockerinstall::compose
    PRECOND
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          gitlab_url: 'https://gitlab',
          registration_token: 'QQnhTdSTszmbJF',
        }
      end

      it { is_expected.to compile }

      it {
        is_expected.to contain_file('/srv/gitlab-runner/config')
          .with_ensure('directory')
          .that_comes_before('Dockerinstall::Composeservice[gitlab/runner]')
      }

      it {
        is_expected.to contain_dockerimage('gitlab/gitlab-runner:v14.0.1')
      }

      it {
        is_expected.to contain_dockerinstall__composeservice('gitlab/runner')
          .with_configuration(%r{^[ ]{6}- /srv/gitlab-runner/config:/etc/gitlab-runner$})
      }
    end
  end
end
