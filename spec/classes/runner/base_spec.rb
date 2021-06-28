# frozen_string_literal: true

require 'spec_helper'

describe 'gitlabinstall::runner::base' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_file('/srv/gitlab-runner')
          .with_ensure('directory')
      }
    end
  end
end
