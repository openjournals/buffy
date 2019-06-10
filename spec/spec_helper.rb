require 'rack/test'
require 'rspec'
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

ENV['RACK_ENV'] = 'test'

require File.expand_path '../../buffy.rb', __FILE__

module RSpecMixin
  include Rack::Test::Methods
  def app() described_class end

  def json_fixture(file_name)
    File.open(File.dirname(__FILE__) + '/support/fixtures/' + file_name, 'rb').read
  end

  def erb_response(file_name)
    File.open(File.expand_path '../responses/' + file_name, 'rb').read
  end

  def fixture(file_name)
    File.dirname(__FILE__) + '/support/fixtures/' + file_name
  end
end

RSpec.configure do |config|
  config.before(:each) do
    stub_request(:any, /api.github.com/).to_rack(FakeGitHub)
  end

  config.mock_with :rspec do |mocks|
    mocks.allow_message_expectations_on_nil = true
  end

  config.include RSpecMixin
end
