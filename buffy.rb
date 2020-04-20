require 'pry'
require 'sinatra/base'
require 'sinatra/config_file'

require_relative 'sinatra/webhook_parser'
require_relative 'responder.rb'
require_relative 'responder_group.rb'

Dir[File.join(__dir__, 'responders', '*.rb')].each { |file| require file }

class Buffy < Sinatra::Base
  register Sinatra::ConfigFile
  register Sinatra::WebhookParser
  parse_webhook

  config_file "config/settings.yml"

  get '/' do
    "Hi!"
  end

  post '/dispatch' do
    responders.respond(@message, @context)
  end

  def responders
    @responders ||= begin
      rg = ResponderGroup.new(settings.responders)
      rg.load_responders!
      rg
    end
  end
end
