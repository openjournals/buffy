require_relative '../lib/responder'

class CloseIssueCommandResponder < Responder

  keyname :close_issue_command

  def define_listening
    required_params :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\.?\s*$/i
  end

  def process_message(message)
    close_issue
    process_labeling
  end

  def default_description
    "Close the issue"
  end

  def default_example_invocation
    "@#{bot_name} #{command}"
  end
end
