require_relative '../lib/responder'

class LabelCommandResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    label_issue(labels)
  end

  def command
    if params[:command].nil? || params[:command].strip.empty?
      raise "Configuration Error in LabelCommandResponder: No value for command."
    else
      @command ||= params[:command].strip
    end
    @command
  end

  def labels
    if params[:labels].nil? || !params[:labels].is_a?(Array) || params[:labels].uniq.compact.empty?
      raise "Configuration Error in LabelCommandResponder: No labels specified."
    else
      @labels ||= params[:labels].uniq.compact
    end
    @labels
  end

  def description
    "Label issue with: #{labels.join(', ')}"
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
