# @summary SMTP settings for GitLab
#
# SMTP settings for GitLab
# See https://docs.gitlab.com/omnibus/settings/smtp.html
#     https://api.rubyonrails.org/classes/ActionMailer/Base.html
#
# @example
#   include gitlabinstall::smtp
class gitlabinstall::smtp (
  String  $user_name                = $gitlabinstall::smtp_user_name,
  String  $password                 = $gitlabinstall::smtp_password,
  Stdlib::Fqdn
          $address                  = $gitlabinstall::smtp_address,
  Optional[Stdlib::Fqdn]
          $domain                   = $gitlabinstall::smtp_domain,
  Optional[String]
          $gitlab_email_from        = $gitlabinstall::gitlab_email_from,
  Integer $port                     = 587,
  Enum['login', 'plain']
          $authentication           = 'login',
  Boolean $enable_starttls_auto     = true,
  Enum['none', 'peer']
          $openssl_verify_mode      = 'peer',
) {
  $gitlab_rails = {
    'smtp_enable'               => true,
    'smtp_address'              => $address,
    'smtp_port'                 => $port,
    'smtp_user_name'            => $user_name,
    'smtp_password'             => $password,
    'smtp_domain'               => $domain,
    'smtp_authentication'       => $authentication,
    'smtp_enable_starttls_auto' => $enable_starttls_auto,
    'smtp_openssl_verify_mode'  => $openssl_verify_mode,
    'gitlab_email_from'         => $gitlab_email_from,
  }
}
