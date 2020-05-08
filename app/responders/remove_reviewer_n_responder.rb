require_relative '../lib/responder'

class RemoveReviewerNResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} remove reviewer (\S+)/i
  end

  def process_message(message, context)
    mark = "<!--reviewer-#{@match_data[1]}-->"
    end_mark = "<!--end-reviewer-#{@match_data[1]}-->"
    new_body = issue.body.gsub(/#{mark}(.*)#{end_mark}/i, "#{mark} #{no_reviewer_text} #{end_mark}")

    update_issue(context, { body: new_body })
    respond("Reviewer #{@match_data[1]} removed!", context)
  end

  def no_reviewer_text
    params[:no_reviewer_text] || 'Pending'
  end
end
