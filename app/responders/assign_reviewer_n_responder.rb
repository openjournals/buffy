require_relative '../lib/responder'

class AssignReviewerNResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} assign (.*) as reviewer (\S+)/i
  end

  def process_message(message, context)
    mark = "<!--reviewer-#{@match_data[2]}-->"
    end_mark = "<!--end-reviewer-#{@match_data[2]}-->"
    new_body = issue.body.gsub(/#{mark}(.*)#{end_mark}/i, "#{mark} #{@match_data[1]} #{end_mark}")

    update_issue(context, { body: new_body })
    respond("Reviewer #{@match_data[2]} assigned!", context)
  end
end
