action :create do
  home_prefix = node['mithril_service']['home_dir']
  app_shared = "#{home_prefix}/app/shared"
  gopath = "#{app_shared}/gopath"
  rabbitmq_master = node['mithril_service']['rabbitmq_master']
  release_dest = "#{app_shared}/tmp/#{node['mithril_service']['revision']}"
  starting_port = node['mithril_service']['starting_port']
  cluster_size = node['mithril_service']['cluster']['cluster_size']
  deploy_action = node['mithril_service']['deploy_action'].to_sym

  # OK to do this at the compile phase of Chef
  no_deploy_file = '/tmp/.stingray-refusal-file'
  ::File.delete(no_deploy_file) if ::File.exists?(no_deploy_file)

  # check here since they are explicit dependencies so we don't end up in a bad state
  raise 'RabbitMQ master not provided' unless rabbitmq_master && !rabbitmq_master.empty?

  # These are *supposed* to be created by the deploy resource,
  # but apparently not always...
  short_gopath = 'app/shared/gopath'
  %W(
  app
  app/shared
  app/shared/pids
  app/shared/log
  #{short_gopath}
  #{short_gopath}/bin
  bin
  ).each do |dirname|
    directory "#{home_prefix}/#{dirname}" do
      owner 'mithril'
      mode 0755
      recursive true
    end
  end

  bash 'giving mithril its own home dir' do
    code "chown -R mithril:mithril #{home_prefix}"
  end

  # Other things may need to be changed if the mithril instances will not be run
  # with the same options.
  cluster_size.times do |index|
    template "/etc/init/mithril-service-#{format('%02d', index)}.conf" do
      source 'mithril-service.conf.erb'
      mode 0644
      variables(
        :mithril_home => home_prefix,
        :server_address => ":#{starting_port + index}",
        :amqp_uri => rabbitmq_master,
        :debug_enabled => node['mithril_service']['debug_enabled'],
        :pg_enabled => node['mithril_service']['pg_enabled'],
        :pid_file => node['mithril_service']['pid_file'] || ''
      )
    end
  end

  ### DEPLOYMENT SECTION ###

  if new_resource.stingray_integration_enabled
    stingray_auth = "#{new_resource.stingray_auth_username}:#{new_resource.stingray_auth_password}"

    modcloth_stingray_exec 'stingray-manager' do
      auth stingray_auth
      endpoint new_resource.stingray_endpoint
      node new_resource.stingray_node
      pool new_resource.stingray_pool
      ssl_verify_none new_resource.stingray_ssl_verify_none
      version new_resource.stingray_version
      failure_file no_deploy_file

      action :add_and_drain

      only_if do
        [:deploy, :force_deploy].include?(deploy_action)
      end
    end
  end

  cluster_size.times do |i|
    service 'service-stop' do
      service_name "mithril-service-#{format('%02d', i)}"
      provider Chef::Provider::Service::Upstart
      action :stop

      only_if do
        !::File.exists?(no_deploy_file) &&
          [:deploy, :force_deploy].include?(deploy_action)
      end
    end
  end

  unless new_resource.ignore_default_download_support_files
    remote_file "#{node['install_prefix']}/bin/aws" do
      source 'https://raw.github.com/timkay/aws/master/aws'
      mode 0755
    end

    cookbook_file "#{node['install_prefix']}/bin/s3-download-tarball" do
      source 's3-download-tarball'
      cookbook 'mithril-cluster'
      mode 0755
    end

    file "#{home_prefix}/.awssecret" do
      owner 'mithril'
      group 'mithril'
      mode 0600

      # AWS Access Key ID and Secret Access Key for
      # public-artifacts-download-user, which has list and get-object permissions
      # on the public ModCloth bucket that contains the public Mithril binaries.
      # In case you don't want to host it yourself. :-)
      content <<-EOF.gsub(/^\s+/, '')
        AKIAJKTW32P2LV6AE2LA
        +ExNRzWf+JhM7ZHLjfHzwPOjgnW+txfGcvnsCcs0
      EOF
    end
  end

  tarball_download_command = new_resource.tarball_download_command ||
    "s3-download-tarball 'mithril' " <<
    "'#{node['mithril_service']['revision']}' '#{release_dest}' --go"

  bash 'download mithril binary' do
    path ["#{home_prefix}/bin"]
    user 'mithril'
    group 'mithril'

    code tarball_download_command

    only_if do
      !::File.exists?(no_deploy_file) &&
        [:deploy, :force_deploy].include?(deploy_action)
    end
  end

  bash 'copy mithril binary' do
    code "cp -v '#{release_dest}/mithril/mithril-server' '#{gopath}/bin/'"
    user 'mithril'
    group 'mithril'

    only_if do
      !::File.exists?(no_deploy_file) &&
        [:deploy, :force_deploy].include?(deploy_action)
    end
  end

  link "#{home_prefix}/bin/mithril-server" do
    to "#{gopath}/bin/mithril-server"
    owner 'mithril'
  end


  cluster_size.times do |i|
    service 'service-restart' do
      service_name "mithril-service-#{format('%02d', i)}"
      provider Chef::Provider::Service::Upstart
      action :restart

      only_if do
        !::File.exists?(no_deploy_file) &&
          [:deploy, :force_deploy].include?(deploy_action)
      end
      notifies :undrain, 'modcloth-stingray-exec[stingray-manager]', :immediately if new_resource.stingray_integration_enabled
    end
  end

  ### END DEPLOYMENT SECTION ###

  new_resource.updated_by_last_action(true)
end
