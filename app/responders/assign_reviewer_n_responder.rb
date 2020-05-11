require_relative '../lib/responder'

class AssignReviewerNResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} assign (.*) as reviewer (\S+)/i
  end

  def process_message(message)
    mark = "<!--reviewer-#{@match_data[2]}-->"
    end_mark = "<!--end-reviewer-#{@match_data[2]}-->"

    update_body(mark, end_mark, @match_data[1])
    respond("Reviewer #{@match_data[2]} assigned!")
  end
end
