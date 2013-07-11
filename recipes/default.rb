include_recipe 'golang'

home_prefix = `echo ~mithril`.chomp
raise 'Mithril user not found' if home_prefix =~ /~/

app_shared = "#{home_prefix}/app/shared"
gopath = "#{app_shared}/gopath"
rabbitmq_master = node['mithril_service']['rabbitmq_master']
release_dest = "#{app_shared}/tmp/#{node['mithril_service']['revision']}"
starting_port = node['mithril_service']['starting_port']
cluster_size = node['mithril_service']['cluster']['cluster_size']
deploy_action = node['mithril_service']['deploy_action'].to_sym

# OK to do this at the compile phase of Chef
no_deploy_file = '/tmp/.stingray-refusal-file'
File.delete(no_deploy_file) if ::File.exists?(no_deploy_file)

# check here since they are explicit dependencies so we don't end up in a bad state
raise 'RabbitMQ master not provided' unless rabbitmq_master && !rabbitmq_master.empty?
raise 'PostgreSQL handler enabled but no URI provided' if node['mithril_service']['pg_enabled'] && !pg_master

# These are *supposed* to be created by the deploy resource,
# but apparently not always...
short_gopath = 'app/shared/gopath'
%W(
  app
  app/shared
  app/shared/pids
  app/shared/log
  #{short_gopath}
  #{short_gopath}/src
  #{short_gopath}/bin
  #{short_gopath}/src/github.com
  #{short_gopath}/src/github.com/modcloth
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
      :server_address => ":#{starting_port + index}",
      :amqp_uri => rabbitmq_master,
      :debug_enabled => node['mithril_service']['debug_enabled'],
      :pg_enabled => node['mithril_service']['pg_enabled'],
      :pid_file => node['mithril_service']['pid_file'] || ''
    )
  end
end

### DEPLOYMENT SECTION ###

if node['mithril_service']['stingray']['integration_enabled']
  stingray_auth = "#{node['mithril_service']['stingray']['auth_username']}:#{node['mithril_service']['stingray']['auth_password']}"
  mithril_pool = node['mithril_service']['stingray']['pool']

  modcloth_stingray_exec 'stingray-manager' do
    auth stingray_auth
    endpoint "https://#{stingray_auth}@#{node['mithril_service']['stingray']['endpoint_host']}:9090/soap"
    node "#{node.name}:#{node['mithril_service']['stingray']['listen_port']}"
    pool mithril_pool
    ssl_verify_none node['mithril_service']['stingray']['ssl_verify_none']
    version node['mithril_service']['stingray']['version']
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
      !File.exists?(no_deploy_file) &&
        [:deploy, :force_deploy].include?(deploy_action)
    end
  end
end

bash 'download mithril binary' do
  path ["#{home_prefix}/bin"]
  user 'mithril'
  group 'mithril'

  code %Q{s3-download-tarball 'mithril' } <<
       %Q{'#{node['mithril_service']['revision']}' '#{release_dest}' --go}

  only_if do
    !File.exists?(no_deploy_file) &&
      [:deploy, :force_deploy].include?(deploy_action)
  end
end

bash 'copy mithril binary' do
  code "cp -v '#{release_dest}/mithril/mithril-server' '#{gopath}/bin/'"
  user 'mithril'
  group 'mithril'

  only_if do
    !File.exists?(no_deploy_file) &&
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
      !File.exists?(no_deploy_file) &&
        [:deploy, :force_deploy].include?(deploy_action)
    end
    notifies :undrain, 'modcloth-stingray-exec[stingray-manager]', :immediately if node['mithril_service']['stingray']['integration_enabled']
  end
end

### END DEPLOYMENT SECTION ###
