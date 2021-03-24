require_relative '../lib/responder'

class RemoveEditorResponder < Responder

  keyname :remove_editor

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} remove editor\s*\z/i
  end

  def process_message(message)
    mark = "<!--editor-->"
    end_mark = "<!--end-editor-->"

    old_editor = read_from_body(mark, end_mark)

    update_body(mark, end_mark, no_editor_text)
    remove_assignee(old_editor) if (old_editor != no_editor_text && username?(old_editor))
    respond("Editor removed!")
    process_labeling
  end

  def no_editor_text
    params[:no_editor_text] || 'Pending'
  end

  def description
    "Remove the editor assigned to this submission"
  end

  def example_invocation
    "@#{bot_name} remove editor"
  end
end
