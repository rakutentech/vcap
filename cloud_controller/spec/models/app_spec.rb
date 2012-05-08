require 'spec_helper'

describe App do
  it "must have an owner"
  it "requires a unique name/owner combination"
  it "specifies a runtime and framework"
  it "defaults to 0 instances when initialized" do
    App.new.instances.should be_zero
  end

  describe "#collaborators" do
    before :each do
      @user_a = create_user('a@foo.com', 'a')
      @user_b = create_user('b@foo.com', 'b')

      @app = App.create(
        :name      => 'foobar',
        :owner     => @user_a,
        :runtime   => 'ruby18',
        :framework => 'sinatra')
      @app.should be_valid
    end

    it "includes the owner by default" do
      @app.collaborator?(@user_a).should be_true
    end

    it "can be added" do
      @app.add_collaborator(@user_b)
      @app.collaborator?(@user_b).should be_true
    end

    it "can be removed" do
      @app.remove_collaborator(@user_a)
      @app.collaborator?(@user_a).should be_false
    end
  end

  describe '#update_run_count' do
    before :each do
      @app = App.new
    end

    it 'resets the run count if the staged package hash changed' do
      @app.expects(:staged_package_hash_changed?).returns(true)
      @app.run_count = 5
      @app.update_run_count()
      @app.run_count.should == 0
    end

    it 'increments the run count if the staged package hash did not change' do
      @app.expects(:staged_package_hash_changed?).returns(false)
      @app.run_count = 5
      @app.update_run_count()
      @app.run_count.should == 6
    end
  end

  describe '#update_staged_package' do
    let(:app) { App.new }

    before :each do
      @tmpdir = Dir.mktmpdir
      AppPackage.stubs(:package_dir).returns(@tmpdir)
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should remove the old package' do
      old_package = create_test_package(@tmpdir)
      app.staged_package_hash = old_package[:name]

      new_package = create_test_package(@tmpdir)
      app.update_staged_package(new_package[:path])

      File.exist?(old_package[:path]).should be_false
    end
  end

  describe "#enforce_app_resources" do
    before :each do
      @user_a = create_user('a@foo.com', 'a')
    end

    it "should not set the resources when 'enforce_app_resources' is null" do
      AppConfig[:enforce_app_resources] = nil
      @app = App.create(
        :name      => 'foobar',
        :owner     => @user_a,
        :runtime   => 'ruby18',
        :framework => 'sinatra')
      @app.should be_valid
      @app.memory.should == 256
      @app.file_descriptors.should == 256  
      @app.disk_quota.should == 2048       
    end

    it "should set the resources when 'enforce_app_resources' is set" do
      AppConfig[:enforce_app_resources] = {
        :memory => 4096,
        :file_descriptors => 65536,
        :disk_quota => 8192
      }
      @app = App.create(
        :name      => 'foobar',
        :owner     => @user_a,
        :runtime   => 'ruby18',
        :framework => 'sinatra')
      @app.should be_valid
      @app.memory.should == 4096
      @app.file_descriptors.should == 65536
      @app.disk_quota.should == 8192 
    end
  end

  def create_user(email, pw)
    u = User.new(:email => email)
    u.set_and_encrypt_password(pw)
    u.save
    u.should be_valid
    u
  end

  def create_test_package(base_dir)
    name = "test_package#{Time.now.to_f}#{Process.pid}"
    ret = {
      :name     => name,
      :path     => File.join(base_dir, name),
      :contents => name,
    }
    File.open(ret[:path], 'w+') {|f| f.write(ret[:contents]) }

    ret
  end
end
