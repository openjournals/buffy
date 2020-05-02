require 'sinatra/base'
require 'sinatra/config_file'
require_relative 'sinatra_ext/github_webhook_filter'
require_relative 'lib/responders_loader'

class Buffy < Sinatra::Base
  include RespondersLoader
  register Sinatra::ConfigFile
  register GitHubWebhookFilter

  config_file "../config/settings-#{settings.environment}.yml"

  post '/dispatch' do
    responders.respond(@message, @gh_context)
    halt 200
  end

  get '/status' do
    "#{settings.buffy[:bot_github_user]} in #{settings.environment}: up and running!"
  end
end
