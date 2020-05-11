require 'octokit'

module GitHub

  # Authenticated Octokit
  def github_client
    @github_client ||= Octokit::Client.new(access_token: @settings[:gh_access_token], auto_paginate: true)
  end

  # Return an Octokit GitHub Issue
  def issue(context=@context)
    @issue ||= github_client.issue(context.repo, context.issue_id)
  end

  # Post messages to a GitHub issue.
  # Context is an OpenStruct created in lib/github_webhook_parser
  def bg_respond(comment, context=@context)
    github_client.add_comment(context.repo, context.issue_id, comment)
  end

  # Add labels to a GitHub issue
  # Context is an OpenStruct created in lib/github_webhook_parser
  def label_issue(labels, context=@context)
    github_client.add_labels_to_an_issue(context.repo, context.issue_id, labels)
  end

  def update_issue(options, context=@context)
    github_client.update_issue(context.repo, context.issue_id, options)
  end

  def authorized_people
    @authorized_people ||= begin
      autorized_logins = []
      authorized_team_ids.each do |team_id|
        autorized_logins += github_client.team_members(team_id).collect { |e| e.login }
      end
      autorized_logins.sort.uniq
    end
  end

  def user_authorized?(user_login)
    @user_authorized ||= begin
      autorized = []
      authorized_team_ids.each do |team_id|
        autorized << github_client.team_member?(team_id, user_login)
        break if autorized.compact.any?
      end
      autorized.compact.any?
    end
  end

end