require 'sinatra/base'
require 'sinatra/config_file'
require_relative 'sinatra_ext/github_webhook_filter'

class Buffy < Sinatra::Base
  register Sinatra::ConfigFile
  register GitHubWebhookFilter

  config_file "../config/settings.yml"

  post '/dispatch' do
    halt 200
  end

  get '/status' do
    "#{settings.bot_github_user} in #{settings.environment}: up and running!"
  end
end
