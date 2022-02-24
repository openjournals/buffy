require_relative '../lib/responder'

class ListTeamMembersResponder < Responder

  keyname :list_team_members

  def define_listening
    required_params :command, :team_id

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\.?\s*\z/i
  end

  def process_message(message)
    team_members = api_team_members(params[:team_id])
    heading = params[:heading].to_s
    respond_template :list_team_members, { heading: heading, team_members: team_members }
  end

  def default_description
    "Replies to '#{command}'"
  end

  def default_example_invocation
    "@#{bot_name} #{command}"
  end
end
