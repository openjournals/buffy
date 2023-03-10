require_relative '../lib/responder'

class UpdateCommentResponder < Responder

  keyname :update_comment

  def define_listening
    required_params :command, :template_file

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\.?\s*$/i
  end

  def process_message(message)
    comment_text = render_external_template(template_file, locals)
    update_comment(context.comment_id, comment_text)
  end

  def default_description
    "Updates sender's comment with the #{template_file} template"
  end

  def default_example_invocation
    "@#{bot_name} #{command}"
  end
end
