require 'sinatra/base'
require 'sinatra/config_file'

class Buffy < Sinatra::Base
  register Sinatra::ConfigFile

  config_file "../config/settings.yml"

  get '/' do
    "Hi! your environment is: #{settings.environment}. Settings: #{settings.bot_name}, #{settings.github_user}"
  end

end
