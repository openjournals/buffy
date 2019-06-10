require 'ostruct'
require 'sinatra/base'
require 'json'
require 'pry'

module Sinatra
  module ResponderParser
    # def parse_webhook(settings)
    def load_responders
      before {
        @responders ||= begin
          rg = Array.new
          rg.load_responders!
          rg
        end
      }
    end
  end

  register ResponderParser
end
