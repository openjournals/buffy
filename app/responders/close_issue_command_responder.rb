require_relative '../lib/responder'

class CloseIssueCommandResponder < Responder

  def define_listening
    required_params :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    close_issue(labels_options)
    process_removing_labels
  end

  def labels_options
    labels_to_add.empty? ? {} : {labels: labels_to_add}
  end

  def description
    params[:description] || "Close the issue"
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
