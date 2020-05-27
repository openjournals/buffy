require_relative '../lib/responder'

class AssignEditorResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} assign (\S+) as editor\s*\z/i
  end

  def process_message(message)
    mark = "<!--editor-->"
    end_mark = "<!--end-editor-->"

    new_editor = @match_data[1]
    new_editor = "@#{context.sender}" if new_editor == "me"

    update_body(mark, end_mark, new_editor)
    add_collaborator(new_editor) if add_as_collaborator?
    add_assignee(new_editor) if add_as_assignee?
    respond("Assigned! #{new_editor} is now the editor")
  end

  def description
    "Assign a user as the editor of this submission"
  end

  def example_invocation
    "@#{@bot_name} assign @username as editor"
  end

  def add_as_collaborator?
    params[:add_as_collaborator] == true
  end

  def add_as_assignee?
    true unless params[:add_as_assignee] == false
  end

end
