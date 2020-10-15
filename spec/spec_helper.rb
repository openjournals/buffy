require 'rack/test'
require 'rspec'
require 'webmock/rspec'
require 'sidekiq/testing'
require 'sidekiq/api'
WebMock.disable_net_connect!(allow_localhost: true)

ENV['RACK_ENV'] = 'test'

require_relative  '../app/buffy.rb'
Dir["#{File.expand_path '../support', __FILE__}/**/*.rb"].sort.each { |f| require f }

module RSpecMixin
  include Rack::Test::Methods
  def app() Buffy end

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
    Sidekiq::Worker.clear_all
    stub_request(:any, /api.github.com/).to_rack(FakeGitHub)
  end

  config.mock_with :rspec do |mocks|
    mocks.allow_message_expectations_on_nil = true
  end

  config.include RSpecMixin
  config.include CommonActions
  config.include ResponderParams
end
