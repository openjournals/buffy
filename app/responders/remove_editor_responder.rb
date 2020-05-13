require_relative '../lib/responder'

class RemoveEditorResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} remove editor\s*\z/i
  end

  def process_message(message)
    mark = "<!--editor-->"
    end_mark = "<!--end-editor-->"

    update_body(mark, end_mark, no_reviewer_text)
    respond("Editor removed!")
  end

  def no_reviewer_text
    params[:no_reviewer_text] || 'Pending'
  end

  def description
    "Remove the editor assigned to this submission"
  end

  def example_invocation
    "@#{@bot_name} remove editor"
  end
end
