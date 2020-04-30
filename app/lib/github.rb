require 'octokit'

module GitHub
  # Authenticated Octokit

  def github_client
    @github_client ||= Octokit::Client.new(:access_token => ENV['GH_TOKEN'],
                                           :auto_paginate => true)
  end

  # Post messages to a GitHub issue.
  # Context is an OpenStruct created in sinatra/webhook_parser
  def bg_respond(comment, context)
    github_client.add_comment(context.nwo, context.issue_id, comment)
  end

  # Add labels to a GitHub issue
  # Context is an OpenStruct created in sinatra/webhook_parser
  def label_issue(languages, context)
    github_client.add_labels_to_an_issue(context.nwo, context.issue_id, languages)
  end
end