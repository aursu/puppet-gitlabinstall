# @summary GitLab installation
#
# GitLab installation
#
# @example
#   include gitlabinstall
#
# @param gitlab_package_ensure
#   RPM package version. For example, 13.3.2-ce.0.el7 (see https://packages.gitlab.com/gitlab/gitlab-ce)
#
# @param external_url
#   Configuring the external URL for GitLab
#   see [Configuring the external URL for GitLab](https://docs.gitlab.com/omnibus/settings/configuration.html#configuring-the-external-url-for-gitlab)
#
# @param database_password
#   PostgreSQL database password
#
# @param manage_cert_data
#   Whether provided certificate and key should be installed on server or not
#
# @param cert_identity
#   Certificate name to use in order to lookup certificate data in Puppet Hiera
#
# @param external_postgresql_service
#   Using a non-packaged PostgreSQL database management server
#   see [Using a non-packaged PostgreSQL database management server](https://docs.gitlab.com/omnibus/settings/database.html#using-a-non-packaged-postgresql-database-management-server)
#
# @param manage_postgresql_core
#   Whether to manage PostgreSQL core or not (installation, initialization,
#   service start)
#
# @param pg_tools_setup
#   Whether to setup system pg_dump and psql tools into /opt/gitlab/bin path
#   See https://docs.gitlab.com/omnibus/settings/database.html#backup-and-restore-a-non-packaged-postgresql-database
#   for details
#
# @param non_bundled_web_server
#   Whether to use bundled into GitLab Nginx service or not
#
# @param manage_nginx_core
#   Whether to manage core settings for Nginx or not (installation, nginx.conf
#   setup, service setup)
#
# @param external_registry_service
#   Whether to integrate external Container registry into GitLab or not
#
# @param registry_host
#   Registry endpoint without the scheme, the address that gets shown to the end user.
#
# @param registry_port
#   Registry endpoint port, visible to the end user
#
# @param registry_api_url
#   Registry API URL Gitlab should connect to
#
# @param ldap_enabled
#   Whether to enable LDAP settings or not
#
# @param ldap_base
#   LDAP base where we can search for users.
#
# @param ldap_password
#   The password of the LDAP bind user.
#
# @param ldap_host
#   IP address or domain name of your LDAP server.
#
class gitlabinstall (
  String  $gitlab_package_ensure       = '13.0.10-ce.0.el7',
  Stdlib::HTTPUrl
          $external_url                = 'http://localhost',
  Variant[Stdlib::Fqdn, Stdlib::IP::Address]
          $database_host               = 'localhost',
  Boolean $manage_cert_data            = true,
  Optional[String]
          $cert_identity               = undef,
  Boolean $external_postgresql_service = true,
  Boolean $manage_postgresql_core      = true,
  Boolean $pg_tools_setup              = true,
  Boolean $non_bundled_web_server      = true,
  Boolean $manage_nginx_core           = true,
  Boolean $external_registry_service   = false,
  Optional[Stdlib::Fqdn]
          $registry_host               = undef,
  Integer $registry_port               = 443,
  Stdlib::HTTPUrl
          $registry_api_url            = 'http://localhost:5000',
  Optional[String]
          $database_password           = undef,
  Array[Stdlib::IP::Address]
          $monitoring_whitelist        = [],
  Boolean $ldap_enabled                = false,
  Optional[String]
          $ldap_base                   = undef,
  Optional[String]
          $ldap_password               = undef,
  Optional[String]
          $ldap_host                   = undef,
)
{
  # extract GitLab hostname from its sexternal_url (see Omnibus installation
  # manual for external_url description)
  $urldata = split($external_url, '/')
  if $urldata[0] in ['http:', 'https:', ''] and $urldata[1] == '' {
    $server_name = $urldata[2]
    $subfolder = $urldata[3]
  }
  else {
    $server_name = $urldata[0]
    $subfolder = $urldata[1]
  }

  if $subfolder == '' or $subfolder == undef {
    $relative_url = ''
    $server_path = '/'
  }
  else {
    $relative_url = "/${subfolder}"
    $server_path = "/${subfolder}"
  }
}
