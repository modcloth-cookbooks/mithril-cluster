
describe 'mithril-cluster::default' do
  let(:chef_run) do
    ChefSpec::ChefRunner.new(
      step_into: ['mithril-cluster'],
      log_level: :error
    ) do |node|
      node.normal['mithril_service']['rabbitmq_master'] = 'stub'
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
end
