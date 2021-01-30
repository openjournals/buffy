require_relative '../lib/responder'

class CloseIssueCommandResponder < Responder

  def define_listening
    required_params :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    close_issue
    process_labeling
  end

  def description
    params[:description] || "Close the issue"
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
