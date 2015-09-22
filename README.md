# pmtprovider

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with pmtprovider](#setup)
    * [What pmtprovider affects](#what-pmtprovider-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with pmtprovider](#beginning-with-pmtprovider)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

This is a Puppet custom provider for the package type called 'pmt', that allows
you to manage installation, removal and upgrade of puppet modules.

## Module Description

The provider shells out puppet using the puppet module face, the reason for not using
the puppet module api directly in code was that the puppet execution responsible
for ensuring state could inadvertently carry over configuration that affects
what the state should look like. For example, --module_repository is set
based on configuration or command line arguments to the puppet agent | apply
execution, by shelling out the puppet command we have more flexibility in
that regard since we can just parameterize the execution on our own.

## Setup

### What pmtprovider affects

* A provider 'pmt' to the package resource type

### Beginning with pmtprovider

Installing the module using the pmt:

```
puppet module install unibet-pmtprovider
```

## Usage

Some sample usages using the provider

Installing the puppetlabs-apache puppet module:

```
  package { 'puppetlabs-apache':
    ensure   => present,
    provider => pmt
  }
```

Installing puppetlabs-apache in a custom location:

```
  package { 'puppetlabs-apache':
    ensure   => present,
    provider => pmt,
    install_options => [
      {
        '--modulepath' => '/custom/location'
      }
    ]
  }
```

Installing company-privatemodule using a custom forge:

```
  package { 'company-privatemodule':
    ensure   => present,
    provider => pmt,
    install_options => [
      {
        '--module_repository' => 'https://forge.company.example.com'
      }
    ]
  }
```

The provider also supports version pinning and the use of symbols such as latest and absent.

## Reference

See usage

## Limitations

* Zero tests
* Use at your own risk

## Development

If you want to contribute please send in a pull request, eventually when we have
tests in place we'd prefer that your changes passes the spec tests before it
gets merged
