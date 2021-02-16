require_relative '../lib/responder'

class LabelCommandResponder < Responder

  keyname :label_command

  def define_listening
    required_params :command
    check_labels_present

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    process_labeling
  end

  def check_labels_present
    if labels_to_add.empty? && labels_to_remove.empty?
      raise "Configuration Error in LabelCommandResponder: No labels specified."
    end
  end

  def description
    add_labels = labels_to_add.empty? ? nil : "Label issue with: #{labels_to_add.join(', ')}"
    remove_labels = labels_to_remove.empty? ? nil : "Remove labels: #{labels_to_remove.join(', ')}"

    [add_labels, remove_labels].compact.join(". ")
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
