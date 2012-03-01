require 'spec_helper'

describe 'VMC::Cli::Command::Apps' do

  include WebMock::API

  before(:all) do
    @target = VMC::DEFAULT_TARGET
    @local_target = VMC::DEFAULT_LOCAL_TARGET
    @user = 'derek@gmail.com'
    @password = 'foo'
    @auth_token = spec_asset('sample_token.txt')
  end

  before(:each) do
    # make sure these get cleared so we don't have tests pass that shouldn't
    RestClient.proxy = nil
    ENV['http_proxy'] = nil
    ENV['https_proxy'] = nil
  end

  it 'should not fail when there is an attempt to upload an app with links internal to the root' do
    @client = VMC::Client.new(@local_target, @auth_token)

    login_path = "#{@local_target}/users/#{@user}/tokens"
    stub_request(:post, login_path).to_return(File.new(spec_asset('login_success.txt')))
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))

    app = spec_asset('tests/node/node_npm')
    options = {
        :name => 'foo',
        :uris => ['foo.vcap.me'],
        :instances => 1,
        :staging => { :model => 'nodejs/1.0' },
        :path => app,
        :resources => { :memory => 64 }
    }
    command = VMC::Cli::Command::Apps.new(options)
    command.client(@client)

    app_path = "#{@local_target}/#{VMC::APPS_PATH}/foo"
    stub_request(:get, app_path).to_return(File.new(spec_asset('app_info.txt')))

    resource_path = "#{@local_target}/#{VMC::RESOURCES_PATH}"
    stub_request(:post, resource_path).to_return(File.new(spec_asset('resources_return.txt')))

    app_upload_path = "#{@local_target}/#{VMC::APPS_PATH}/foo/application"
    stub_request(:post, app_upload_path)

    stub_request(:put, app_path)

    # Both 'vmc push ..' and 'vmc update ..' ultimately end up calling
    # the client 'update' command. The 'update' command determines the list
    # of files to upload (via the 'resources' end-point), uploads the needed
    # files and then starts up the app. The check for unreachable links
    # is made prior to the resource check.
    command.update('foo')

    a_request(:post, app_upload_path).should have_been_made.once
    a_request(:put, app_path).should have_been_made.once

  end

  it 'should fail when there is an attempt to upload an app with links reaching outside the app root' do
    @client = VMC::Client.new(@local_target, @auth_token)

    login_path = "#{@local_target}/users/#{@user}/tokens"
    stub_request(:post, login_path).to_return(File.new(spec_asset('login_success.txt')))
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))

    app = spec_asset('tests/node/app_with_external_link')
    options = {
        :name => 'foo',
        :uris => ['foo.vcap.me'],
        :instances => 1,
        :staging => { :model => 'nodejs/1.0' },
        :path => app,
        :resources => { :memory => 64 }
    }
    command = VMC::Cli::Command::Apps.new(options)
    command.client(@client)

    app_path = "#{@local_target}/#{VMC::APPS_PATH}/foo"
    stub_request(:get, app_path).to_return(File.new(spec_asset('app_info.txt')))

    expect { command.update('foo')}.to raise_error(/Can't deploy application containing links/)
  end

  describe "env commands" do
    before do
      client = VMC::Client.new(@local_target, @auth_token)

      login_path = "#{@local_target}/users/#{@user}/tokens"
      stub_request(:post, login_path).to_return(File.new(spec_asset('login_success.txt')))
      info_path = "#{@local_target}/#{VMC::INFO_PATH}"
      stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))

      app = spec_asset('tests/node/app_with_external_link')
      options = {
          :name => 'foo',
          :uris => ['foo.vcap.me'],
          :instances => 1,
          :staging => { :model => 'nodejs/1.0' },
          :path => app,
          :resources => { :memory => 64 }
      }
      app_path = "#{@local_target}/#{VMC::APPS_PATH}/foo"
      stub_request(:get, app_path).to_return(File.new(spec_asset('app_info.txt')))
      @command = VMC::Cli::Command::Apps.new(options)
      @command.client(client)
    end

    context "when specified system-reserved key" do
      it "environments whose prefixes are VMC_ should not be added." do
        @command.should_receive(:display).with("VCAP_ and VMC_ reserved by system.")
        a_request(:put, "#{@local_target}/#{VMC::APPS_PATH}/foo").should_not have_been_made

        @command.environment_add('foo', 'VMC_FOO=BAR')
      end
      it "environments whose prefixes are VCAP_ should not be added." do
        @command.should_receive(:display).with("VCAP_ and VMC_ reserved by system.")
        a_request(:put, "#{@local_target}/#{VMC::APPS_PATH}/foo").should_not have_been_made

        @command.environment_add('foo', 'VCAP_FOO=BAR')
      end
    end
    context "when specified invalid key" do
      it "keys started with ' should not be added." do
        invalid_key = ""
        @command.should_receive(:display).with("#{invalid_key} is invalid key.")
        a_request(:put, "#{@local_target}/#{VMC::APPS_PATH}/foo").should_not have_been_made

        @command.environment_add('foo', invalid_key, 'bar')
      end
    end
  end

end
