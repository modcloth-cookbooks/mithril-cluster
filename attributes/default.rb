default['mithril_service']['revision'] = 'master'
default['mithril_service']['deploy_action'] = 'deploy'
default['mithril_service']['pg_enabled'] = false
default['mithril_service']['debug_enabled'] = true
default['mithril_service']['starting_port'] = 8371
default['mithril_service']['home_dir'] = '/home/mithril'
default['mithril_service']['ignore_default_download_support_files'] = false
default['mithril_service']['service_config_cookbook'] = 'mithril-cluster'

default['mithril_service']['cluster']['cluster_size'] = 1

default['install_prefix'] = (
  {
    'solaris2' => '/opt/local',
    'smartos' => '/opt/local'
  }.fetch(node['platform'], '/usr/local')
)
