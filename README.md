mithril-cluster Cookbook
========================

[![Build Status](https://travis-ci.org/modcloth-cookbooks/mithril-cluster.png?branch=master)](https://travis-ci.org/modcloth-cookbooks/mithril-cluster)

This cookbook is intended to be plug-and-play for downloading a binary
for the [mithril](https://github.com/modcloth-labs/mithril) application
and getting it running on a Linux box.  If you want more information on
why you would use mithril in the first place, see
[this](http://rafecolton.github.io/other/2013-07-08-mithril-not-just-for-dwarves-anymore.html)
article.

This cookbook does not currently
support SmartOS because, as of writing, Go doesn't compile on SmartOS.
As soon as it does, SmartOS support will be added.  This cookbook also
integrates with
[modcloth-stingray-exec](https://github.com/modcloth-cookbooks/modcloth-stingray-exec)
to allow automation of a node's membership in a Stingray pool.  This
functionality is not required, just optional.  It is also possible to
configure this cookbook to download and install your own tarball, though
ModCloth has provided credentials to download a public version of the
binary.

It is very important to note that in order to deploy a mithril cluster,
**you will need several components that this cookbook does NOT
provide**.  They are:

* a base role and bootstrap script for your machine
* creation of a `mithril` user on the machine (*NOTE:* This cookbook
  assumes that you have a user on the machine named `mithril` that will
be responsible for executing the downloaded binaries.  If you don not
have such a user, the cookbook will explode at the beginning of the
compile phase.)
* writing the `.pgpass` file into the mithril user's home directory -
  used in `templates/default/mithril-service-conf.erb` and expects the
[standard
format](http://www.postgresql.org/docs/9.1/static/libpq-pgpass.html)
* creation of your database and user on the `pg_master` database
* an `nginx` configuration for your application (not required, but
  highly recommended for managing SSL and round-robining to the
application instances on a given machine)

Requirements
------------

platform:

* supports ubuntu
* probably works on other linux flavors but currently untested (feel
  free to submit a pull request)
* will support SmartOS just as soon as Go compiles on it

suggests:

* `golang` - since the applications are pre-compiled, it is not actually
  necessary to install Go on the machine.  However, Go 1.1.1 it is required if
you want to compile the application on the machine, and it is also
generally useful to have for debugging.
* `modcloth-stingray-exec` - necessary if you want to want to include
  the stingray automation bits, but since those are not required,
neither is the `modcloth-stingray-exec` cookbook

Attributes
----------

#### mithril-cluster::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['mithril_service']['revision']</tt></td>
    <td>String</td>
    <td>which binary revision to download</td>
    <td><tt>'latest'</tt></td>
  </tr>
  <tr>
    <td><tt>['mithril_service']['deploy_action']</tt></td>
    <td>String</td>
    <td>whether or not to deploy</td>
    <td><tt>'deploy'</tt></td>
  </tr>
  <tr>
    <td><tt>['mithril_service']['pg_enabled']</tt></td>
    <td>Boolean</td>
    <td>whether or not postgres is enabled</td>
    <td><tt>false</tt></td>
  </tr>
  <tr>
    <td><tt>['mithril_service']['debug_enabled']</tt></td>
    <td>Boolean</td>
    <td>whether or not mithril prints debugging statements</td>
    <td><tt>true</tt></td>
  </tr>
  <tr>
    <td><tt>['mithril_service']['cluster_size']</tt></td>
    <td>Integer</td>
    <td>number of application instances per machine</td>
    <td><tt>2</tt></td>
  </tr>
  <tr>
    <td><tt>['mithril_service']['starting_port']</tt></td>
    <td>Integer</td>
    <td>port number for first mithril instance</td>
    <td><tt>8371</tt></td>
  </tr>
  <tr>
    <td><tt>['install_prefix']</tt></td>
    <td>String</td>
    <td>prefix for installing executables/binaries</td>
    <td><tt>'/usr/local'</tt></td>
  </tr>
</table>

Usage
-----

### Simple

The simple usage is just `mithril_cluster 'cluster-name'` in a recipe or
`recipe[mithril_cluster]` in a role

### With Stingray

If you want to automate stingray, you would do something like the
following:

```ruby
mithril_cluster 'cluster-name' do
  stingray_auth_password "#{password}"
  stingray_auth_username "#{username}"
  stingray_endpoint "https://#{stingray_auth}@#{stingray_uri}:9090/soap"
  stingray_integraiton_enabled true
  stingray_node "#{node_name}:#{nginx_or_mithril_listen_port}"
  stingray_pool "mithril_pool"
  stingray_ssl_verify_none '1'
  stingray_version '9.1'
end
```

### With Custom Binary Download

By default, the `mithril-cluster` cookbook uses
[`aws`](https://github.com/timkay/aws) as well as the custom
`s3-download-tarball` scripts to download a public tarball for you.  If
you want to download your own tarball, you must specify the
`tarball_download_command` attribute.  This attribute is run as the
`code` attribute inside a bash block, so it can be any command or script
you have written to the box.  Just remember that you need to specify any
environmental variables you need as part of the command, as they will
not be include via the provider.

**NOTE: If you download your own tarball, you MUST place the binary in the
following location:**

```ruby
"#{home_prefix}/app/shared/tmp/#{node['mithril_service']['revision']}/mithril/mithril-server"
# where home_prefix is the home directory of the mithril user
```
**That is where `mithril-cluster` expects to find it for further
operations.**

If you want to use a custom tarball download command and you therefore
do not want to write the `aws` and `s3-download-tarball` scripts as well
as the ModCloth public `.awssecret` to the box, you may specify the
`ignore_default_download_support_files true` attribute.

Contributing
------------

See [CONTRIBUTING](CONTRIBUTING.md)

License and Authors
-------------------

See [LICENSE](LICENSE.txt) and [AUTHORS](AUTHORS.md)
