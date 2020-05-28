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

    old_reviewer = read_from_body(mark, end_mark)
    old_reviewer = nil unless username?(old_reviewer)

    update_body(mark, end_mark, new_reviewer)
    add_collaborator(new_reviewer) if add_as_collaborator?
    replace_assignee(old_reviewer, new_reviewer) if add_as_assignee?
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

  def add_as_assignee?
    true unless params[:add_as_assignee] == false
  end

end
