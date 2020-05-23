require_relative '../lib/responder'

class AssignReviewerNResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} assign (\S+) as reviewer (\S+)\s*\z/i
  end

  def process_message(message)
    mark = "<!--reviewer-#{@match_data[2]}-->"
    end_mark = "<!--end-reviewer-#{@match_data[2]}-->"

    new_reviewer = @match_data[1]

    update_body(mark, end_mark, new_reviewer)
    add_collaborator(new_reviewer) if add_as_collaborator?
    respond("Reviewer #{@match_data[2]} assigned!")
  end

  def description
    "Assign a user as the reviewer N of this submission (where N=1,2...)"
  end

  def example_invocation
    "@#{@bot_name} assign @username as reviewer 2"
  end

  def add_as_collaborator?
    true unless params[:add_as_collaborator] == false
  end

end
