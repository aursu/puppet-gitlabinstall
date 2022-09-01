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
# @param user_filter
#   Filter LDAP users. Format: RFC 4515
#
# @param full_name
#   LDAP attribute for user display name. If no full name could be found at the
#   attribute specified for `name`, the full name is determined using the
#   attributes specified for `first_name` and `last_name`.
#
# @param first_name
#   LDAP attribute for user first name.
#
# @param last_name
#   LDAP attribute for user last name.
#
# @param email
#   LDAP attribute for user email.
#
# @param provider_id
#   LDAP server provider ID
#
class gitlabinstall::ldap (
  String  $provider_id                   = 'main',
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
  Optional[String]
          $user_filter                   = undef,
  Optional[String]
          $full_name                     = undef,
  Optional[String]
          $first_name                    = undef,
  Optional[String]
          $last_name                     = undef,
  Optional[String]
          $email                         = undef,
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

  $main_user_filter = $user_filter ? {
    String => { 'user_filter' => $user_filter },
    default => {}
  }

  $main_full_name = $full_name ? {
    String => { 'name' => $full_name },
    default => {}
  }

  $main_first_name = $first_name ? {
    String => { 'first_name' => $first_name },
    default => {}
  }

  $main_last_name = $last_name ? {
    String => { 'last_name' => $last_name },
    default => {}
  }

  $main_email = $email ? {
    String => { 'email' => $email },
    default => {}
  }

  $gitlab_rails = {
    'ldap_enabled'         => true,
    'prevent_ldap_sign_in' => $prevent_ldap_sign_in,
    'ldap_servers'         => {
      $provider_id => {
        'active_directory'              => $active_directory,
        'allow_username_or_email_login' => $allow_username_or_email_login,
        'base'                          => $base,
        'block_auto_created_users'      => $block_auto_created_users,
        'host'                          => $host,
        'encryption'                    => $encryption,
        'password'                      => $password,
        'port'                          => $port,
        'uid'                           => $uid,
      } +
      $main_bind_dn +
      $main_group_base +
      $main_user_filter +
      $main_full_name +
      $main_first_name +
      $main_last_name +
      $main_email
    }
  }
}
