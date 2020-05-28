require_relative '../lib/responder'

class RemoveReviewerNResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} remove reviewer (\S+)\s*\z/i
  end

  def process_message(message)
    mark = "<!--reviewer-#{@match_data[1]}-->"
    end_mark = "<!--end-reviewer-#{@match_data[1]}-->"

    old_reviewer = read_from_body(mark, end_mark)

    update_body(mark, end_mark, no_reviewer_text)
    remove_assignee(old_reviewer) if (old_reviewer != no_reviewer_text && username?(old_reviewer))
    respond("Reviewer #{@match_data[1]} removed!")
  end

  def no_reviewer_text
    params[:no_reviewer_text] || 'Pending'
  end

  def description
    "Remove the user assigned as reviewer N of this submission (where N=1,2...)"
  end

  def example_invocation
    "@#{@bot_name} remove reviewer 2"
  end
end
