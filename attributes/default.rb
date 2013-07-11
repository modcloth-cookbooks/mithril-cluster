default['mithril_service']['revision'] = 'latest'
default['mithril_service']['deploy_action'] = 'deploy'
default['mithril_service']['pg_enabled'] = false
default['mithril_service']['debug_enabled'] = true
default['mithril_service']['starting_port'] = 8371

default['mithril_service']['cluster']['cluster_size'] = 2

default['mithril_service']['stingray']['integration_enabled'] = false
default['mithril_service']['stingray']['version'] = '9.1'
default['mithril_service']['stingray']['ssl_verify_none'] = '1'

# intended to be overwritten by node
# attributes, just here for reference
default['mithril_service']['stingray']['auth_username'] = ''
default['mithril_service']['stingray']['auth_password'] = ''
default['mithril_service']['stingray']['pool'] = ''
default['mithril_service']['stingray']['endpoint_host'] = ''
default['mithril_service']['stingray']['listen_port'] = ''

default['install_prefix'] = (
  {
    'solaris2' => '/opt/local',
    'smartos' => '/opt/local'
  }.fetch(node['platform'], '/usr/local')
)
