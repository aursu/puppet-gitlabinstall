# @summary Setup LDAP settings for GitLab instance
#
# Setup LDAP settings for GitLab instance
# see https://docs.gitlab.com/ee/administration/auth/ldap/
#
# @example
#   include gitlabinstall::ldap
#
# @param base
#   Base where we can search for users.
#
# @param prevent_ldap_sign_in
#   When using another system such as SAML for authentication it can be
#   desirable to disable LDAP for authentication. In particular LDAP can be a
#   useful technology for synchronizing group membership, while being a
#   security risk for sign in due to the way passwords are handled. Additionally
#   it can allow users to bypass 2FA policies.
#
# @param active_directory
#   This setting specifies if LDAP server is Active Directory LDAP server. For
#   non-AD servers it skips the AD specific queries. If your LDAP server is not
#   AD, set this to false.
#
# @param allow_username_or_email_login
#   If enabled, GitLab will ignore everything after the first @ in the LDAP
#   username submitted by the user on sign-in. If you are using uid:
#   `userPrincipalName` on ActiveDirectory you need to disable this setting,
#   because the userPrincipalName contains an @.
#
# @param bind_dn
#   The full DN of the user you will bind with.
#
# @param block_auto_created_users
#   To maintain tight control over the number of active users on your GitLab
#   installation, enable this setting to keep new users blocked until they have
#   been cleared by the admin.
#
# @param group_base
#   Base used to search for groups.
#
# @param host
#   IP address or domain name of your LDAP server.
#
# @param label
#   A human-friendly name for your LDAP server. It will be displayed on your
#   sign-in page.
#
# @param encryption
#   Encryption method. The `method` key is deprecated in favor of `encryption`.
#   The `encryption` value `simple_tls` corresponds to 'Simple TLS' in the LDAP
#   library. `start_tls` corresponds to StartTLS, not to be confused with
#   regular TLS. Normally, if you specify `simple_tls` it will be on port 636,
#   while `start_tls` (StartTLS) would be on port 389. `plain` also operates on
#   port 389. Removed values: `tls` was replaced with `start_tls` and `ssl` was
#   replaced with `simple_tls`.
#
# @param password
#   The password of the bind user.
#
# @param port
#   The port to connect with on your LDAP server. 389 or 636 (for SSL)
#
# @param uid
#   LDAP attribute for username. Should be the attribute, not the value that
#   maps to the `uid`.
#
class gitlabinstall::ldap (
  String  $base                          = $gitlabinstall::ldap_base,
  String  $password                      = $gitlabinstall::ldap_password,
  Variant[Stdlib::Fqdn, Stdlib::IP::Address]
          $host                          = $gitlabinstall::ldap_host,
  Integer $port                          = 636,
  Enum['userPrincipalName', 'sAMAccountName', 'uid']
          $uid                           = 'uid',
  Enum['simple_tls', 'start_tls', 'plain']
          $encryption                    = 'simple_tls',
  String  $label                         = 'LDAP',
  Boolean $prevent_ldap_sign_in          = false,
  Boolean $active_directory              = false,
  Boolean $allow_username_or_email_login = false,
  Boolean $block_auto_created_users      = true,
  Optional[String]
          $bind_dn                       = undef,
  Optional[String]
          $group_base                    = undef,
)
{
  $main_group_base = $group_base ? {
    String => { 'group_base' => $group_base },
    default => {}
  }

  $main_bind_dn = $bind_dn ? {
    String => { 'bind_dn' => $bind_dn },
    default => {}
  }

  $gitlab_rails = {
    'ldap_enabled'         => true,
    'prevent_ldap_sign_in' => $prevent_ldap_sign_in,
    'ldap_servers'         => {
      'main' => {
        'active_directory'              => $active_directory,
        'allow_username_or_email_login' => $allow_username_or_email_login,
        'base'                          => $base,
        'block_auto_created_users'      => $block_auto_created_users,
        'host'                          => $host,
        'encryption'                    => $encryption,
        'password'                      => $password,
        'port'                          => $port,
      } +
      $main_bind_dn +
      $main_group_base
    }
  }
}
