# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include gitlabinstall::ssl
#
# @param server_name
#   GitLab server name (must be part of external_url)
#
# @param cert_identity
#   Certificate name to use in order to lookup certificate data in Puppet Hiera
#   Hiera lookup keys are `<cert_identity>_private` and `<cert_identity>_certificate`
#   where `<cert_identity>` is normalized value following next rules:
#
#   '*' -> 'wildcard', '.' -> '_', '-' -> '_', "'" ->  '_' and ' ' -> '_'
#
#   cert_identity must match either certificate Common Name or any of Subject
#   alternate DNS name
#
# @param ssl_cert
#   Content of x509 certificate to use for GitLab TLS setup
#
# @param ssl_key
#   Content of RSA private key to use for GitLab TLS setup
#
# @param manage_cert_data
#   Whether provided certificate and key should be installed on server
#   or not
#
class gitlabinstall::ssl (
  Stdlib::Fqdn $server_name,
  Boolean $manage_cert_data = $gitlabinstall::manage_cert_data,
  Optional[String] $cert_identity = $gitlabinstall::cert_identity,
  Optional[String] $ssl_cert = undef,
  Optional[String] $ssl_key = undef,
) {
  include tlsinfo

  # if both SSL cert and key provided via parameters - them have more priority
  # then certificate identity for lookup
  if $ssl_cert and $ssl_key {
    $cert_lookupkey = $server_name
    $certdata       = $ssl_cert

    if $manage_cert_data {
      # we use Hiera for certificate/private key storage
      tlsinfo::certpair { $cert_lookupkey:
        identity => true,
        cert     => $ssl_cert,
        pkey     => $ssl_key,
        # in case of self signed CA
        strict   => false,
      }
    }
  }
  else {
    if $cert_identity {
      $cert_lookupkey = $cert_identity
    }
    else {
      $cert_lookupkey = $server_name
    }

    $certdata = tlsinfo::lookup($cert_lookupkey)

    if $manage_cert_data {
      # we use Hiera for certificate/private key storage
      tlsinfo::certpair { $cert_lookupkey:
        identity => true,
      }
    }
  }

  # we use default locations for certificate and key storage - get
  # these locations
  $ssl_cert_path = tlsinfo::certpath($certdata)
  $ssl_key_path = tlsinfo::keypath($certdata)
}
