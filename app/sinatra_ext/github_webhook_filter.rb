require 'sinatra/extension'
require 'issue'

module GitHubWebhookFilter
  extend Sinatra::Extension

  # Make command matching tolerant of whitespace the user didn't intend:
  # GitHub's @-mention autocomplete appends a space (leading to double spaces),
  # and copy-pasting can bring tabs, non-breaking spaces or zero-width characters.
  # Runs of horizontal whitespace become a single space; line breaks are kept.
  def self.space_trim_message(text)
    return text if text.nil?
    text.gsub(/[\u200B-\u200D\u2060\uFEFF]/, "")
        .gsub(/[[:blank:]]+/, " ")
        .gsub(/ *\r?\n */, "\n")
        .strip
  end

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
        @message = GitHubWebhookFilter.space_trim_message(@context.comment_body || @context.issue_body)
      end
    end
  end

end
