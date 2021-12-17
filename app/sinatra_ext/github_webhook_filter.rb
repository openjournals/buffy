require 'sinatra/extension'
require 'issue'

module GitHubWebhookFilter
  extend Sinatra::Extension

  before '/dispatch' do
    if request.request_method == 'POST'
      webhook = Issue::Webhook.new(secret_token: settings.buffy[:env][:gh_secret_token],
                                   discard_sender: { settings.buffy[:env][:bot_github_user] => ["issue_comment"]},
                                   accept_events: ["issues", "issue_comment"])
      payload, error = webhook.parse_request(request)

      if webhook.errored?
        halt error.status, error.message
      else
        @context = payload.context
        @message = @context.comment_body || @context.issue_body
      end
    end
  end

end
