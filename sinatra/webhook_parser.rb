require 'ostruct'
require 'sinatra/base'
require 'json'
require 'pry'

module Sinatra
  module WebhookParser
    # def parse_webhook(settings)
    def parse_webhook
      before {
        begin
          payload = JSON.parse(request.env["rack.input"].read)
          @event = request.env["X-GitHub-Event"]
        rescue JSON::ParserError
          halt 500
        end

        halt 422 if payload.nil?
        halt 422 if @event.nil?
        # halt 422 unless @config = settings.configs[@nwo]

        @action = payload['action']
        @payload = payload

        if @action == 'opened' || @action == 'closed'
          @message = payload['issue']['body']
        elsif @action == 'created'
          @message = payload['comment']['body']
        end

        @sender = payload['sender']['login']
        @issue_id = payload['issue']['number']
        @nwo = payload['repository']['full_name']

        @context = OpenStruct.new(
          :action => @action,
          :event => @event,
          :issue_id => @issue_id,
          :message => @message,
          :nwo => @nwo,
          :payload => @payload,
          :sender => @sender,
          :event_action => "#{@event}.#{@action}"
        )
      }
    end
  end

  register WebhookParser
end
