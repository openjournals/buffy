require_relative '../lib/responder'

class AssignEditorResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} assign (.*) as editor\s*\z/i
  end

  def process_message(message)
    mark = "<!--editor-->"
    end_mark = "<!--end-editor-->"

    update_body(mark, end_mark, @match_data[1])
    respond("Assigned! #{@match_data[1]} is now the editor")
  end

  def description
    "Assign a user as the editor of this submission"
  end

  def example_invocation
    "@#{@bot_name} assign @username as editor"
  end

end
