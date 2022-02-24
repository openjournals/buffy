require_relative '../lib/responder'

class AssignEditorResponder < Responder

  keyname :assign_editor

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} (assign|add) (\S+) as editor\.?\s*\z/i
  end

  def process_message(message)
    mark = "<!--editor-->"
    end_mark = "<!--end-editor-->"

    new_editor = @match_data[2]
    new_editor = "@#{context.sender}" if new_editor == "me"

    old_editor = read_from_body(mark, end_mark)
    old_editor = nil unless username?(old_editor)

    update_body(mark, end_mark, new_editor)
    add_collaborator(new_editor) if add_as_collaborator?
    replace_assignee(old_editor, new_editor) if add_as_assignee?
    respond("Assigned! #{new_editor} is now the editor")

    process_external_service(params[:external_call], locals.merge({editor: new_editor})) if params[:external_call]
    process_labeling
  end

  def default_description
    "Assign a user as the editor of this submission"
  end

  def default_example_invocation
    "@#{bot_name} assign @username as editor"
  end

  def add_as_collaborator?
    params[:add_as_collaborator] == true
  end

  def add_as_assignee?
    true unless params[:add_as_assignee] == false
  end

end
