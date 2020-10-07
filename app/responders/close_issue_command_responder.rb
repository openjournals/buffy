require_relative '../lib/responder'

class CloseIssueCommandResponder < Responder

  def define_listening
    required_params :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    close_issue(labels_options)
  end

  def labels
    if params[:labels].nil? || !params[:labels].is_a?(Array) || params[:labels].uniq.compact.empty?
      @labels = []
    else
      @labels ||= params[:labels].uniq.compact
    end

    @labels
  end

  def labels_options
    labels.empty? ? {} : {labels: labels}
  end

  def description
    if labels.empty?
      "Close the issue"
    else
      "Label the issue with: [#{labels.join(', ')}] and close it."
    end
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
