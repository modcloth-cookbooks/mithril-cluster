
describe 'mithril-cluster::default' do
  let(:chef_run) do
    ChefSpec::ChefRunner.new(
      step_into: ['mithril-cluster'],
      log_level: :error
    ) do |node|
      node.normal['mithril_service']['rabbitmq_master'] = 'stub'
      node.normal['mithril_service']['pg_enabled'] = true
    end.converge described_recipe
  end

  shared_examples 'deploy_directory' do
    it "creates the required directory" do
      chef_run.should create_directory dir
    end

    it 'assigns the correct permissions' do
      chef_dir.mode.should == 0755
    end

    it 'assigns the mithril user as the directory owner' do
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
    let(:dir) { dir }
    let(:chef_dir) { chef_run.directory(dir) }
    include_examples 'deploy_directory'
  end

  it 'creates upstart configuration files' do
    now = Time.now
    Time.stub(:now).and_return(now)
    %w(00 01).each do |num|
      chef_run.should create_file_with_content "/etc/init/mithril-service-#{num}.conf", <<-EOF.gsub(/^ {6}/, '').chomp
      # Dropped off by Chef recipe[mithril::cluster] #{now}
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
end
