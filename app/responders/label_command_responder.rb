require_relative '../lib/responder'

class LabelCommandResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    label_issue(labels) unless labels.empty?

    unless labels_to_remove.empty?
      (labels_to_remove & issue_labels).each {|label| unlabel_issue(label)}
    end
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
      if labels_to_remove.empty?
        raise "Configuration Error in LabelCommandResponder: No labels specified."
      else
        @labels = []
      end
    else
      @labels ||= params[:labels].uniq.compact
    end

    @labels
  end

  def labels_to_remove
    if params[:remove].nil? || !params[:remove].is_a?(Array) || params[:remove].uniq.compact.empty?
      @labels_to_remove = []
    end

    @labels_to_remove ||= params[:remove].uniq.compact
  end

  def description
    add_labels = labels.empty? ? nil : "Label issue with: #{labels.join(', ')}"
    remove_labels = labels_to_remove.empty? ? nil : "Remove labels: #{labels_to_remove.join(', ')}"

    [add_labels, remove_labels].compact.join(". ")
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
