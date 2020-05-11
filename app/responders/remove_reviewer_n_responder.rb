require_relative '../lib/responder'

class RemoveReviewerNResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} remove reviewer (\S+)/i
  end

  def process_message(message)
    mark = "<!--reviewer-#{@match_data[1]}-->"
    end_mark = "<!--end-reviewer-#{@match_data[1]}-->"

    update_body(mark, end_mark, no_reviewer_text)
    respond("Reviewer #{@match_data[1]} removed!")
  end

  def no_reviewer_text
    params[:no_reviewer_text] || 'Pending'
  end
end
