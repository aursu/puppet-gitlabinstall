# frozen_string_literal: true

require 'spec_helper'

describe 'gitlabinstall::smtp' do
  let(:pre_condition) { 'include gitlabinstall' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          user_name: 'wp00000000-noreply',
          password: 'secret',
        }
      end

      it { is_expected.to compile }
    end
  end
end
