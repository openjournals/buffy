require 'sinatra/extension'
require_relative '../github_webhook_parser'

module GitHubWebhookFilter
  extend Sinatra::Extension

  before '/dispatch' do
    if request.request_method == 'POST'
      verify_signature
      parse_webhook
    end
  end

  def self.registered(app)
    app.class_eval { include GitHubWebhookParser }
    super
  end
end