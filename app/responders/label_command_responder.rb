require_relative '../lib/responder'

class LabelCommandResponder < Responder

  def define_listening
    required_params :command
    check_labels_present

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    label_issue(labels_to_add) unless labels_to_add.empty?

    unless labels_to_remove.empty?
      (labels_to_remove & issue_labels).each {|label| unlabel_issue(label)}
    end
  end

  def check_labels_present
    if labels_to_add.empty? && labels_to_remove.empty?
      raise "Configuration Error in LabelCommandResponder: No labels specified."
    end
  end

  def labels_to_add
    if params[:add_labels].nil? || !params[:add_labels].is_a?(Array) || params[:add_labels].uniq.compact.empty?
      @labels_to_add = []
    end

    @labels_to_add ||= params[:add_labels].uniq.compact
  end

  def labels_to_remove
    if params[:remove_labels].nil? || !params[:remove_labels].is_a?(Array) || params[:remove_labels].uniq.compact.empty?
      @labels_to_remove = []
    end

    @labels_to_remove ||= params[:remove_labels].uniq.compact
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
