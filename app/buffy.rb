require 'sinatra/base'
require 'sinatra/config_file'
require_relative 'github_webhook_parser'

class Buffy < Sinatra::Base
  include GithubWebhookParser
  register Sinatra::ConfigFile

  config_file "../config/settings.yml"

  before '/dispatch' do
    verify_signature
    parse_webhook
  end

  post '/dispatch' do
    halt 200
  end

  get '/status' do
    "#{settings.bot_github_user} in #{settings.environment}: up and running!"
  end
end
