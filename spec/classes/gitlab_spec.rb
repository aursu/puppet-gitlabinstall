# frozen_string_literal: true

require 'spec_helper'

puppet_sslcert = {
  'hostcert' => {
    'path' => '/etc/puppetlabs/puppet/ssl/certs/gitlab.domain.tld.pem',
    'data' => '-----BEGIN CERTIFICATE-----
MIIDezCCAmOgAwIBAgIBAjANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxQdXBw
ZXQgQ0E6IHB1cHBldC5kb21haW4udGxkMB4XDTIwMDkxMDIwMzkxM1oXDTIxMDkx
MDIwMzkxM1owHDEaMBgGA1UEAwwRZ2l0bGFiLmRvbWFpbi50bGQwggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQCqUh5O9lE0ArMRzvzeXaIrqIlIjWZFzS72
4qQ+NFX5x+cmsrpKn2EZQBGe06410nQWNuWdtUgldMBlA/AKXvJELNYo/OIjBwAa
zf9lKKD4TdWqB+OnbrlNHHGFVNCbCjIHy+0ZO34CeTn/f8IR/UadLp32CgCxX/pi
HPkdMZOJ4OD04zEQH5hRL69bCEaIGeqxWifrYjtY6NLP8eZdzYDb+smX8mF47TL8
geUy9C3owNNxfFxJ352Q9TLh8pHEIvBBE4aU0VSEQYYemKhPb5FfzntZ++1WKRgt
DbsPHe49zGW3XUGaT8RakImlLaNzwFukLHoUQc2c5pN/GuwWAZy/AgMBAAGjgbww
gbkwNwYJYIZIAYb4QgENBCoWKFB1cHBldCBSdWJ5L09wZW5TU0wgSW50ZXJuYWwg
Q2VydGlmaWNhdGUwDgYDVR0PAQH/BAQDAgWgMCAGA1UdJQEB/wQWMBQGCCsGAQUF
BwMBBggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBSkAuzYqYjiGZ8H
Fylh/TFu1ShZxTAfBgNVHSMEGDAWgBS1nyWNzIAheLXbl7+ad7b5UBRXoDANBgkq
hkiG9w0BAQsFAAOCAQEAZdbaHB5JFVV9fpEwbBFM235yGVQATdgB8SXDpn/KTKX8
FfyzHxJ5QX0Fb9deR0ZhgXesa0S5QOvyQTN0R00fjaV8KKlXDiElQKmxcaHhtD21
N+W9tiRmKqLinvA8dPYOByL6nWSF2PMRkiTHxjO2+YBBYCCGYJsygdIA5RaD/Cou
51CNxbKKpcrsO+kmKSxmZC97V67xRD4Z3DeaGVYcV7nLzwHO4tbZlUKHtlPRXo8M
a/sYFsthasPKSnjtGup40hJdpeuc4IPy3k5yjB6nmgNSmm/V7+4rOhB7VAbukc79
z2FjmEt7Mf+o3qNO/6/yGZipvb0zjTzcZhnxGaM7oQ==
-----END CERTIFICATE-----
',
  },
  'localcacert' => {
    'path' => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
    'data' => '-----BEGIN CERTIFICATE-----
MIIDgTCCAmmgAwIBAgIBATANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxQdXBw
ZXQgQ0E6IHB1cHBldC5kb21haW4udGxkMB4XDTIwMDkxMDIwMzUxMVoXDTMwMDkw
ODIwMzUxMVowJzElMCMGA1UEAwwcUHVwcGV0IENBOiBwdXBwZXQuZG9tYWluLnRs
ZDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJgXuAvAms0dNPxObJg
Mk6u9JgSyiQn/RHMxECGaF3M5vpvi9r6raARtT+RGsqoyo+Max/HFpiZXUmzEbDG
XuxrmhtlNaqIx1AnDw/E61ZDad9/VsLnC+NTwrV7EFZGzTNHSQGyqeb7aOmqTlui
nSZPv4ZQAdnwMeoLdnXCV1ezQ7H1+6ZxJeBprABkYG2/gYFFdpYCuvmFh/m0uWEz
mBrx844Yi/SLtAhY3LEnjLnxSjsyGC1wQ/V+vbxFaeG5BIl/kVVqGXgoY58N6ndJ
m4GcAobPO5UIAxDj8HsZSQTjmzbQBh01eSDr239Auem+EfCPE3VJOli0zynAKg9/
CaMCAwEAAaOBtzCBtDA3BglghkgBhvhCAQ0EKhYoUHVwcGV0IFJ1YnkvT3BlblNT
TCBJbnRlcm5hbCBDZXJ0aWZpY2F0ZTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/
BAUwAwEB/zAdBgNVHQ4EFgQUtZ8ljcyAIXi125e/mne2+VAUV6AwOQYDVR0jBDIw
MKErpCkwJzElMCMGA1UEAwwcUHVwcGV0IENBOiBwdXBwZXQuZG9tYWluLnRsZIIB
ATANBgkqhkiG9w0BAQsFAAOCAQEAmwpFypAWQ9F4cMfGvE44b9h6NQSM9DjShb7j
U9eadbUQ6l8i/ddskQ1IDdh0BV0TVeatX4OhdwmeNmF433BJwzrwqbd3GaoCivUX
tHzwFLi++J32aCBTqMolRCR6okzAQzdaE1fZzM4YGoet0XtecYKCxIWIzlXDAAu/
0eOG2F5RScqsWz/L/DDNeqDMSm1qpIiwiFVBXGSTCwAF5DhrMI9H7SoPKjrPltI7
wYdeHV72guqAp8vOZSP4MiM2dkhY7QIdin6AAIKrps+wFqAEJvYscIY5HOw2AOTy
ROxDS2uWHhQk6CjTo9U9CCKi76v9Pkg5Tv0uTo1KKfDeJuvSUA==
-----END CERTIFICATE-----
',
  },
  'hostprivkey' => {
    'path' => '/etc/puppetlabs/puppet/ssl/private_keys/gitlab.domain.tld.pem',
  },
  'hostpubkey' => {
    'path' => '/etc/puppetlabs/puppet/ssl/public_keys/gitlab.domain.tld.pem',
    'data' => '-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqlIeTvZRNAKzEc783l2i
K6iJSI1mRc0u9uKkPjRV+cfnJrK6Sp9hGUARntOuNdJ0FjblnbVIJXTAZQPwCl7y
RCzWKPziIwcAGs3/ZSig+E3Vqgfjp265TRxxhVTQmwoyB8vtGTt+Ank5/3/CEf1G
nS6d9goAsV/6Yhz5HTGTieDg9OMxEB+YUS+vWwhGiBnqsVon62I7WOjSz/HmXc2A
2/rJl/JheO0y/IHlMvQt6MDTcXxcSd+dkPUy4fKRxCLwQROGlNFUhEGGHpioT2+R
X857WfvtVikYLQ27Dx3uPcxlt11Bmk/EWpCJpS2jc8BbpCx6FEHNnOaTfxrsFgGc
vwIDAQAB
-----END PUBLIC KEY-----
',
  },
  'hostreq' => {
    'path' => '/etc/puppetlabs/puppet/ssl/certificate_requests/gitlab.domain.tld.pem',
    'data' => '-----BEGIN CERTIFICATE REQUEST-----
MIICnzCCAYcCAQAwHDEaMBgGA1UEAwwRZ2l0bGFiLmRvbWFpbi50bGQwggEiMA0G
CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCqUh5O9lE0ArMRzvzeXaIrqIlIjWZF
zS724qQ+NFX5x+cmsrpKn2EZQBGe06410nQWNuWdtUgldMBlA/AKXvJELNYo/OIj
BwAazf9lKKD4TdWqB+OnbrlNHHGFVNCbCjIHy+0ZO34CeTn/f8IR/UadLp32CgCx
X/piHPkdMZOJ4OD04zEQH5hRL69bCEaIGeqxWifrYjtY6NLP8eZdzYDb+smX8mF4
7TL8geUy9C3owNNxfFxJ352Q9TLh8pHEIvBBE4aU0VSEQYYemKhPb5FfzntZ++1W
KRgtDbsPHe49zGW3XUGaT8RakImlLaNzwFukLHoUQc2c5pN/GuwWAZy/AgMBAAGg
PjA8BgkqhkiG9w0BCQ4xLzAtMB0GA1UdDgQWBBSkAuzYqYjiGZ8HFylh/TFu1ShZ
xTAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQCOt66RVxnisLiBccBp
E6wDH1fn1iiEJEkbN7zSmjGUWttyADVWYa3yAEFcd4Qt+32GQW5+Zsq75Lf5p7L1
NnPAmiXfAprxv7fm4h22Jgv/9xKTzT2blZElCY0x9engGDEZOS+KMDDaZ/PZnCOu
Xy6Pc3xtg25GzfLQ406lqYbmyBrrRu0kWPYnR8/OtwcoT+KjIuibwkuRuvGDDVbQ
5nShJxx7BcYIpHAsgDCiCQcGUntgSrMFY6diKip1eyplhyCY8sSFr6drAIJQt4sE
E32dLRRGEoEV7eWthNpEf7yrt8aoWwRXGrdFYwBslvzTU9GYOZ+ElZGgXlXT7zp7
OsAB
-----END CERTIFICATE REQUEST-----
',
  },
}

describe 'gitlabinstall::gitlab' do
  let(:pre_condition) do
    <<-PRECOND
    class { 'gitlabinstall': external_url => 'https://ci.domain.tld' }
    tlsinfo::certificate { 'f1453246': }
    PRECOND
  end

  on_supported_os.each do |os, os_facts|
    os_facts[:puppet_sslcert] = puppet_sslcert
    os_facts[:os]['selinux'] = { 'enabled' => true }
    os_facts[:clientcert] = 'gitlab.domain.tld'

    context "on #{os}" do
      let(:facts) { os_facts.merge(stype: 'gitlab') }
      let(:params) do
        {
          database_password: 'MySecretPassword',
        }
      end

      it { is_expected.to compile }

      context 'with remote container registry' do
        let(:pre_condition) do
          <<-PRECOND
          class { 'gitlabinstall':
            external_url  => 'https://ci.domain.tld',
            registry_host => 'gitlab.domain.tld',
          }

          tlsinfo::certificate { 'f1453246': }
          PRECOND
        end

        let(:params) do
          super().merge(
            'external_registry_service' => true,
          )
        end

        it { is_expected.to compile }

        it {
          is_expected.to contain_file('internal_key')
            .with_path('/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key')
            .with_source('file:///etc/puppetlabs/puppet/ssl/private_keys/gitlab.domain.tld.pem')
            .that_requires('Class[gitlab]')
        }

        it {
          expect(exported_resources).to contain_file('registry_rootcertbundle')
            .with_path('/etc/docker/registry/tokenbundle.pem')
            .with_content(puppet_sslcert['hostcert']['data'])
            .with_tag('ci.domain.tld')
        }
      end

      context 'with LDAP settings' do
        let(:pre_condition) do
          <<-PRECOND
          class { 'gitlabinstall':
            external_url  => 'https://ci.domain.tld',
            ldap_enabled  => true,
            ldap_host     => 'ldap.mydomain.com',
            ldap_password => 'secret',
            ldap_base     => 'ou=people,dc=gitlab,dc=example',
          }

          tlsinfo::certificate { 'f1453246': }
          PRECOND
        end

        it { is_expected.to compile }
      end

      context 'with backup through cron' do
        let(:params) do
          super().merge(
            backup_cron_enable: true,
            gitlab_package_ensure: '16.5.2-ce.0.el8',
          )
        end

        it { is_expected.to compile }

        it {
          is_expected.to contain_cron('gitlab backup')
            .with_command('/opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1 SKIP=builds,artifacts 2>&1')
            .with_hour(3)
            .with_minute(0)
        }

        it {
          is_expected.to contain_file('/usr/libexec/gitlab')
            .with_ensure(:directory)
        }

        it {
          is_expected.to contain_file('/usr/libexec/gitlab/gitlab_config_backup.sh')
            .with_ensure(:file)
            .with_content(%r{^gitlab_version="16\.5\.2"$})
            .with_content(%r{^backup_path="/var/opt/gitlab/backups"$})
        }

        it {
          is_expected.to contain_cron('gitlab config backup')
            .with_command('/usr/libexec/gitlab/gitlab_config_backup.sh 2>&1')
            .with_hour(3)
            .with_minute(0)
        }

        it {
          is_expected.to contain_cron('gitlab backups cleanup')
            .with_command('/usr/bin/find /var/opt/gitlab/backups -mmin +7200 -delete')
            .with_hour('*/4')
            .with_minute(0)
        }
      end

      context 'with artifacts mount enabled' do
        let(:params) do
          super().merge(
            mnt_artifacts: '/dev/mapper/data-gitlab--artifacts',
          )
        end

        it {
          is_expected.to contain_mount('/var/opt/gitlab/gitlab-rails/shared/artifacts')
            .with_ensure('mounted')
            .with_device('/dev/mapper/data-gitlab--artifacts')
            .with_fstype('ext4')
            .that_comes_before('Class[gitlab]')
        }
      end
    end
  end
end
