require 'octokit'
require 'faraday'

# This module includes all the methods involving calls to the GitHub API
# It reuses a memoized Octokit::Client instance
# Context is an OpenStruct object created in lib/github_webhook_parser or in a BuffyWorker
module GitHub

  # Authenticated Octokit
  def github_client
    @github_client ||= Octokit::Client.new(access_token: github_access_token, auto_paginate: true)
  end

  # GitHub access token
  def github_access_token
    @github_access_token ||= env[:gh_access_token]
  end

  # GitHub API headers
  def github_headers
    @github_headers ||= { "Authorization" => "token #{github_access_token}",
                          "Content-Type" => "application/json",
                          "Accept" => "application/vnd.github.v3+json" }
  end

  # returns the URL for a given template in the repo
  def template_url(filename)
    github_client.contents(context.repo, path: template_path + filename).download_url
  end

  # Return an Octokit GitHub Issue
  def issue
    @issue ||= github_client.issue(context.repo, context.issue_id)
  end

  # Return the body of issue
  def issue_body
    @issue_body ||= context.issue_body
    @issue_body ||= issue.body
  end

  # Post messages to a GitHub issue.
  def bg_respond(comment)
    github_client.add_comment(context.repo, context.issue_id, comment)
  end

  # Add labels to a GitHub issue
  def label_issue(labels)
    github_client.add_labels_to_an_issue(context.repo, context.issue_id, labels)
  end

  # Remove a label from a GitHub issue
  def unlabel_issue(label)
    github_client.remove_label(context.repo, context.issue_id, label)
  end

  # List labels of a GitHub issue
  def issue_labels
    github_client.labels_for_issue(context.repo, context.issue_id).map { |l| l[:name] }
  end

  # Update a Github comment
  def update_comment(comment_id, content)
    github_client.update_comment(context.repo, comment_id, content)
  end

  # Update a Github issue
  def update_issue(options)
    github_client.update_issue(context.repo, context.issue_id, options)
  end

   # Close a Github issue
  def close_issue(options = {})
    github_client.close_issue(context.repo, context.issue_id, options)
  end

  # Add a user as collaborator to the repo
  def add_collaborator(username)
    username = user_login(username)
    github_client.add_collaborator(context.repo, username)
  end

  # Add a user to the issue's assignees list
  def add_assignee(username)
    username = user_login(username)
    github_client.add_assignees(context.repo, context.issue_id, [username])
  end

  # Remove a user from the issue's assignees list
  def remove_assignee(username)
    username = user_login(username)
    github_client.remove_assignees(context.repo, context.issue_id, [username])
  end

  # Remove a user from repo's collaborators
  def remove_collaborator(username)
    username = user_login(username)
    github_client.remove_collaborator(context.repo, username)
  end

  # Uses the GitHub API to determine if a user is already a collaborator of the repo
  def is_collaborator?(username)
    username = user_login(username)
    github_client.collaborator?(context.repo, username)
  end

  # Uses the GitHub API to determine if a user is already a collaborator of the repo
  def can_be_assignee?(username)
    username = user_login(username)
    github_client.check_assignee(context.repo, username)
  end

  # Uses the GitHub API to determine if a user has a pending invitation
  def is_invited?(username)
    username = user_login(username)
    github_client.repository_invitations(context.repo).any? { |i| i.invitee.login.downcase == username }
  end

  # Uses the GitHub API to get a user's information
  def get_user(username)
    username = user_login(username)
    begin
      github_client.user(username)
    rescue Octokit::Unauthorized
      logger.warn("Error calling GitHub API! Bad credentials: TOKEN is invalid")
      nil
    rescue Octokit::NotFound
      nil
    end
  end

  # Uses the GitHub API to create a new organization's team.
  # This require the auth user to be owner in the organization
  # Returns true if the response status is 201, false otherwise.
  def add_new_team(org_team_name)
    org_name, team_name = org_team_name.split('/')
    begin
      new_team = github_client.create_team(org_name, { name: team_name })
    rescue Octokit::ClientError => gh_err
      logger.warn("Error trying to create team #{org_team_name}: #{gh_err.message}")
      return false
    end
    return new_team
  end

  # Uses the GitHub API to obtain the id of an organization's team
  def team_id(org_team_name)
    org_name, team_name = org_team_name.split('/')
    raise "Configuration Error: Invalid team name: #{org_team_name}" if org_name.nil? || team_name.nil?
    begin
      team = github_client.organization_teams(org_name).select { |t| t[:slug] == team_name || t[:name].downcase == team_name.downcase }.first
      team.nil? ? nil : team[:id]
    rescue Octokit::Forbidden
      raise "Configuration Error: No API access to organization: #{org_name}"
    end
  end

  # Send an invitation to a user to join an organization's team using the GitHub API
  def invite_user_to_team(username, org_team_name)
    username = user_login(username)
    invitee = get_user(username)
    return false if (invitee.nil? || invitee.id.nil?)

    invited_team_id = team_id(org_team_name)
    if invited_team_id.nil?
      invited_team_id = add_new_team(org_team_name)
      invited_team_id = invited_team_id.id if invited_team_id
    end
    return false unless invited_team_id

    org_name, team_name = org_team_name.split('/')
    url = "https://api.github.com/orgs/#{org_name}/invitations"
    parameters = { invitee_id: invitee.id, team_ids: [invited_team_id] }

    response = Faraday.post(url, parameters.to_json, github_headers)
    response.status.between?(200, 299)
  end

  # Use the GitHub API to trigger a workflow run (GitHub Action)
  def trigger_workflow(repo, workflow, inputs={}, ref="main")
    return false if repo.nil? || workflow.nil?

    url = "https://api.github.com/repos/#{repo}/actions/workflows/#{workflow}/dispatches"
    parameters = { inputs: inputs, ref: ref }
    response = Faraday.post(url, parameters.to_json, github_headers)

    response.status.to_i == 204
  end

  # Returns true if the user in a team member of any of the authorized teams
  # false otherwise
  def user_in_authorized_teams?(user_login)
    @user_authorized ||= begin
      authorized = []
      authorized_team_ids.each do |team_id|
        authorized << github_client.team_member?(team_id, user_login)
        break if authorized.compact.any?
      end
      authorized.compact.any?
    end
  end

  # The url of the invitations page for the current repo
  def invitations_url
    "https://github.com/#{context.repo}/invitations"
  end

  # Returns the user login (removes the @ from the username)
  def user_login(username)
    username.strip.sub(/^@/, "").downcase
  end

  # Returns true if the string is a valid GitHub isername (starts with @)
  def username?(username)
    username.match?(/\A@/)
  end


  module ClassMethods
    # Class method to get team ids for teams configured by name
    def get_team_ids(config)
      teams_hash = config[:teams] || Sinatra::IndifferentHash.new
      gh = nil
      teams_hash.each_pair do |team_name, id_or_slug|
        if id_or_slug.is_a? String
          org_slug, team_slug = id_or_slug.split('/')
          raise "Configuration Error: Invalid team name: #{id_or_slug}" if org_slug.nil? || team_slug.nil?
          gh ||= Octokit::Client.new(access_token: config[:gh_access_token], auto_paginate: true)
          teams_hash[team_name] = begin
            team = gh.organization_teams(org_slug).select { |t| t[:slug] == team_slug || t[:name].downcase == team_slug.downcase }.first
            team.nil? ? nil : team[:id]
          rescue Octokit::Forbidden
            raise "Configuration Error: No API access to organization: #{org_slug}"
          end
        end
      end
      teams_hash
    end
  end

  def self.included base
    base.extend ClassMethods
  end

end