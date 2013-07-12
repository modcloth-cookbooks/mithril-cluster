actions :create

attribute :stingray_auth_password, kind_of: String, default: nil
attribute :stingray_auth_username, kind_of: String, default: nil
attribute :stingray_endpoint, kind_of: String, default: nil
attribute :stingray_integration_enabled, kind_of: [TrueClass, FalseClass], default: false
attribute :stingray_node, kind_of: String, default: nil
attribute :stingray_pool, kind_of: String, default: nil
attribute :stingray_ssl_verify_none, kind_of: String, default: '1'
attribute :stingray_version, kind_of: String, default: '9.1'
attribute :tarball_download_command, kind_of: String, default: nil

default_action :create
