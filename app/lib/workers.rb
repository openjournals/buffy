require 'sidekiq'

Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV["REDIS_URL"],
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
      url: ENV["REDIS_URL"],
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
end

require "#{File.expand_path '../..', __FILE__}/workers/buffy_worker.rb"
Dir["#{File.expand_path '../..', __FILE__}/workers/**/*.rb"].sort.each { |f| require f }