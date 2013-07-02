Description
===========

Installs and configures MariaDB client or server.

A word of caution: I have not tested it on anything beside CentOS 6.4 with chef
solo. I would be happy to accept patches for other platforms!

Requirements
============

Chef 0.10.10+.

Platform
--------

* Debian, Ubuntu
* CentOS, Red Hat, Fedora
* Mac OS X (Using homebrew)

Tested on:

* Debian 5.0, 6.0
* CentOS 6.4

See TESTING.md for information about running tests in Opscode's Test
Kitchen.

Cookbooks
---------

Requires Opscode's openssl cookbook for secure password generation.
See _Attributes_ and _Usage_ for more information.

The RubyGem installation in the `mariadb::ruby` recipe requires a C
compiler and Ruby development headers to be installed in order to
build the mariadb gem.

Requires `homebrew`
[cookbook](http://community.opscode.com/cookbooks/homebrew) on Mac OS
X.

Resources and Providers
=======================

The LWRP that used to ship as part of this cookbook has been
refactored into the
[database](http://community.opscode.com/cookbooks/database)
cookbook. Please see the README for details on updated usage.

Attributes
==========

See the `attributes/server.rb` or `attributes/client.rb` for default
values. Several attributes have values that vary based on the node's
platform and version.

* `node['mariadb']['client']['packages']` - An array of package names
  that should be installed on "client" systems. This can be modified,
  e.g., to specify packages for Percona.
* `node['mariadb']['server']['packages']` - An array of package names
  that should be installed on "server" systems. This can be modified,
  e.g., to specify packages for Percona.

* `node['mariadb']['auto-increment-increment']` -
  auto-increment-increment value in my.cnf
* `node['mariadb']['auto-increment-offset]` - auto-increment-offset
  value in my.cnf
* `node['mariadb']['basedir']` - Base directory where MariaDB is installed
* `node['mariadb']['bind_address']` - Listen address for MariaDBd
* `node['mariadb']['conf_dir']` - Location for mariadb conf directory
* `node['mariadb']['confd_dir']` - Location for mariadb conf.d style
  include directory
* `node['mariadb']['data_dir']` - Location for mariadb data directory
* `node['mariadb']['ec2_path']` - location of mariadb data_dir on EC2
  nodes
* `node['mariadb']['grants_path']` - Path where the grants.sql should be
  written
* `node['mariadb']['mariadbadmin_bin']` - Path to the mariadbadmin binary
* `node['mariadb']['old_passwords']` - Sets the `old_passwords` value in
  my.cnf.
* `node['mariadb']['pid_file']` - Path to the mariadbd.pid file
* `node['mariadb']['port']` - Liten port for MariaDBd
* `node['mariadb']['reload_action']` - Action to take when mariadb conf
  files are modified. Also allows "reload" and "none".
* `node['mariadb']['root_group']` - The default group of the "root" user
* `node['mariadb']['service_name']` - The name of the mariadbd service
* `node['mariadb']['socket']` - Path to the mariadbd.sock file
* `node['mariadb']['use_upstart']` - Whether to use upstart for the
  service provider
* `mariadb['root_network_acl']` - Set define the network the root user will be able to login from, default is nil

Performance and other "tunable" attributes are under the
`node['mariadb']['tunable']` attribute, corresponding to the same-named
parameter in my.cnf, and the default values are used. See
`attributes/server.rb`.

By default, a MariaDB installation has an anonymous user, allowing anyone
to log into MariaDB without having to have a user account created for
them.  This is intended only for testing, and to make the installation
go a bit smoother.  You should remove them before moving into a
production environment.

* `node['mariadb']['remove_anonymous_users']` - Remove anonymous users

Normally, root should only be allowed to connect from 'localhost'.  This
ensures that someone cannot guess at the root password from the network.

* `node['mariadb']['allow_remote_root']` - If true Sets root access from '%'. If false deletes any non-localhost root users.

By default, MariaDB comes with a database named 'test' that anyone can
access.  This is also intended only for testing, and should be removed
before moving into a production environment. This will also drop any user privileges to the test databae and any DB named test_% .

* `node['mariadb']['remove_test_database']` - Delete the test database and access to it.

The following attributes are randomly generated passwords handled in
the `mariadb::server` recipe, using the OpenSSL cookbook's
`secure_password` helper method. These are set using the `set_unless`
node attribute method, which allows them to be easily overridden e.g.
in a role.

* `node['mariadb']['server_root_password']` - Set the server's root
  password
* `node['mariadb']['server_repl_password']` - Set the replication user
  'repl' password
* `node['mariadb']['server_debian_password']` - Set the debian-sys-maint
  user password

## Windows Specific

The following attributes are specific to Windows platforms.

* `node['mariadb']['client']['version']` - The version of MariaDB
  connector to install.
* `node['mariadb']['client']['arch']` - Force 32 bit to work with the
  mariadb gem
* `node['mariadb']['client']['package_file']` - The MSI file for the
  mariadb connector.
* `node['mariadb']['client']['url']` - URL to download the mariadb
  connector.
* `node['mariadb']['client']['packages']` - Similar to other platforms,
  this is the name of the client package.
* `node['mariadb']['client']['basedir']` - Base installation location
* `node['mariadb']['client']['lib_dir']` - Libraries under the base location
* `node['mariadb']['client']['bin_dir']` - binary directory under base location
* `node['mariadb']['client']['ruby_dir']` - location where the Ruby
  binaries will be

Usage
=====

On client nodes, use the client (or default) recipe:

    { "run_list": ["recipe[mariadb::client]"] }

This will install the MariaDB client libraries and development headers
on the system.

On nodes which may use the `database` cookbook's mariadb resources, also
use the ruby recipe. This installs the mariadb RubyGem in the Ruby
environment Chef is using via `chef_gem`.

    { "run_list": ["recipe[mariadb::client]", "recipe[mariadb::ruby]"] }

If you need to install the mariadb Ruby library as a package for your
system, override the client packages attribute in your node or role.
For example, on an Ubuntu system:

    {
      "mariadb": {
        "client": {
          "packages": ["mariadb-client", "libmariadbclient-dev","ruby-mariadb"]
        }
      }
    }

This creates a resource object for the package and does the
installation before other recipes are parsed. You'll need to have the
C compiler and such (ie, build-essential on Ubuntu) before running the
recipes, but we already do that when installing Chef :-).

On server nodes, use the server recipe:

    { "run_list": ["recipe[mariadb::server]"] }

On Debian and Ubuntu, this will preseed the mariadb-server package with
the randomly generated root password in the recipe file. On other
platforms, it simply installs the required packages. It will also
create an SQL file, `/etc/mariadb/grants.sql`, that will be used to set up
grants for the root, repl and debian-sys-maint users.

The recipe will perform a `node.save` unless it is run under
`chef-solo` after the password attributes are used to ensure that in
the event of a failed run, the saved attributes would be used.

On EC2 nodes, use the `server_ec2` recipe and the mariadb data dir will
be set up in the ephmeral storage.

    { "run_list": ["recipe[mariadb::server_ec2]"] }

When the `ec2_path` doesn't exist we look for a mounted filesystem
(eg, EBS) and move the data_dir there.

The client recipe is already included by server and 'default' recipes.

For more infromation on the compile vs execution phase of a Chef run:

* http://wiki.opscode.com/display/chef/Anatomy+of+a+Chef+Run

Chef Solo Note
==============

These node attributes are stored on the Chef
server when using `chef-client`. Because `chef-solo` does not
connect to a server or save the node object at all, to have the same
passwords persist across `chef-solo` runs, you must specify them in
the `json_attribs` file used. For example:

    {
      "mariadb": {
        "server_root_password": "iloverandompasswordsbutthiswilldo",
        "server_repl_password": "iloverandompasswordsbutthiswilldo",
        "server_debian_password": "iloverandompasswordsbutthiswilldo"
      },
      "run_list":["recipe[mariadb::server]"]
    }

License and Author
==================

- Author:: Joshua Timberman (<joshua@opscode.com>)
- Author:: AJ Christensen (<aj@opscode.com>)
- Author:: Seth Chisamore (<schisamo@opscode.com>)
- Author:: Brian Bianco (<brian.bianco@gmail.com>)
- Author:: Jesse Howarth (<him@jessehowarth.com>)
- Author:: Andrew Crump (<andrew@kotirisoftware.com>)

Copyright:: 2009-2013 Opscode, Inc

- Author:: Joe Rocklin (<joe.rocklin@gmail.com>)

Copyright:: 2013 Siemens PLM Software

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
