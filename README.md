# gitlabinstall

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with gitlabinstall](#setup)
    * [What gitlabinstall affects](#what-gitlabinstall-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with gitlabinstall](#beginning-with-gitlabinstall)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

The primary goal of this module is to install GitLab and enable its integration with externally managed Nginx, PostgreSQL, and Docker Registry.

## Setup

### What gitlabinstall affects

The `gitlabinstall` Puppet module installs the gitlab-ce Omnibus package from [packages.gitlab.com/gitlab/gitlab-ce](https://packages.gitlab.com/gitlab/gitlab-ce). The exact package version should be specified.

Additionally, it can manage the setup of Nginx (non-bundled) and PostgreSQL (also non-bundled).

SSL certificates management is also included.


### Setup Requirements

It requires to use custom fork of Puppet Nginx module located on GitHub.

For .fixtures.yml

```
nginx:
  repo: https://github.com/aursu/puppet-nginx.git
  ref: tags/v5.0.1-1
```

and for Puppetfile:

```
mod 'nginx',
  :git => 'https://github.com/aursu/puppet-nginx.git',
  :tag => 'v5.0.1-1'
```

Also requires non-published on Puppet Forge module `aursu::lsys` which is set
of different basic profiles

Puppetfile setup:

```
mod 'lsys',
  :git => 'https://github.com/aursu/puppet-lsys.git',
  :tag => 'v0.21.0'
```

### Beginning with gitlabinstall

Main class for GitLab installation is `gitlabinstall::gitlab`:

```
class { 'gitlabinstall':
  external_url          => 'https://gitlab.domain.tld',
}
class { 'gitlabinstall::gitlab':
  database_password     => 'secret',
  gitlab_package_ensure => '13.3.5-ce.0.el7',
}
```

## Usage

### External container registry integration

Use it with registry installed on separate host and on the same host as PuppetDB:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
  }

  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    # DevCI has PuppetDB which listen on 8080, PuppetDB could be used
    # externally but not GitLab Unicorn
    gitlab_rails_port         => 8008,
    monitoring                => false,
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
    registry_api_url          => 'http://registry.domain.tld:5000',
    gitlab_package_ensure     => '12.10.14-ce.0.el7',
  }
```

Use it with registry on the same host:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
  }

  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
  }
```

### LDAP settings

Basic setup:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
    ldap_enabled          => true,
    ldap_host             => 'ldap.mydomain.com',
    ldap_password         => 'secret',
    ldap_base             => 'ou=people,dc=gitlab,dc=example',
  }

  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
  }
```

With more LDAP settings:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
  }

  class { 'gitlabinstall::ldap':
    host                  => 'ldap.mydomain.com',
    password              => 'secret',
    base                  => 'ou=people,dc=gitlab,dc=example',

    bind_dn               => 'CN=Gitlab,OU=Users,DC=domain,DC=com',
  }

  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
    ldap_enabled              => true,
  }
```

## Reference

See REFERENCE.md

## Limitations

## Development

## Release Notes/Contributors/Etc. **Optional**
