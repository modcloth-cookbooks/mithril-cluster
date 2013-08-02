describe 'mithril-cluster::default' do
  let(:chef_run) do
    ChefSpec::ChefRunner.new(
      step_into: ['mithril-cluster'],
      log_level: :error
    ) do |node|
      node.normal['mithril_service']['rabbitmq_master'] = 'stub'
      node.normal['mithril_service']['pg_enabled'] = true
      node.normal['mithril_service']['cluster']['cluster_size'] = 2
      node.normal['mithril_service']['ignore_default_download_support_files'] = true
    end.converge described_recipe
  end

  shared_examples 'deploy_directory' do |dir|
    it "creates the required directory #{dir}" do
      chef_run.should create_directory dir
    end

    it "assigns the correct permissions to #{dir}" do
      chef_dir = chef_run.directory(dir)
      chef_dir.mode.should == 0755
    end

    it "assigns the mithril user as the owner of #{dir}" do
      chef_dir = chef_run.directory(dir)
      chef_dir.owner.should == 'mithril'
    end
  end

  %w(
    /home/mithril/app
    /home/mithril/app/shared
    /home/mithril/app/shared/pids
    /home/mithril/app/shared/log
    /home/mithril/app/shared/gopath
    /home/mithril/app/shared/gopath/bin
    /home/mithril/bin
  ).each do |dir|
    include_examples 'deploy_directory', dir
  end

  it 'sets home directory permissions' do
    chef_run.should execute_bash_script('giving mithril its own home dir').with(
      code: 'chown -R mithril:mithril /home/mithril'
    )
  end

  it 'creates upstart configuration files' do
    %w(00 01).each do |num|
      chef_run.should create_file_with_content "/etc/init/mithril-service-#{num}.conf", <<-EOF.gsub(/^ {6}/, '').chomp
      # Dropped off by Chef recipe[mithril::cluster]
      description "Mithril Service"

      start on filesystem or runlevel [2345]
      stop on runlevel [!2345]

      setuid mithril
      umask 022

      respawn
      respawn limit 3 10
      chdir /home/mithril
      script
        /home/mithril/bin/mithril-server -a=':#{8371 + num.to_i}' \\
          -amqp.uri='stub' \\
          -pg \\
          -pg.uri=$(awk -F: '{ print "postgres://" $4 ":" $5 "@" $1 "/" $3 "?sslmode=disable"}' /home/mithril/.pgpass 2>/dev/null || echo '') \\
          -d \\
          -p=''
      end script
      EOF
    end
  end

  it 'stops the service' do
    %w(00 01).each do |num|
      chef_run.should stop_service "mithril-service-#{num}"
    end
  end

  it 'runs the tarball download command' do
    chef_run.should execute_bash_script('download mithril binary').with(
      code: "tb download-artifact 'mithril' 'master' '/home/mithril/app/shared/tmp/master' --go"
    )
  end

  it 'creates the mithril-server symlink' do
    chef_run.should create_link('/home/mithril/bin/mithril-server')
  end

  it 'links the mithril server binary to the correct location' do
    link = chef_run.link('/home/mithril/bin/mithril-server')
    link.to.should == '/home/mithril/app/shared/gopath/bin/mithril-server'
  end

  it 'stops the service' do
    %w(00 01).each do |num|
      chef_run.should restart_service "mithril-service-#{num}"
    end
  end
end
