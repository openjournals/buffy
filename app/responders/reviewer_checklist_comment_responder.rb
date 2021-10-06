require_relative '../lib/responder'

class ReviewerChecklistCommentResponder < Responder

  keyname :reviewer_checklist_comment

  def define_listening
    required_params :template_file

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\.?\s*\z/i
  end

  def process_message(message)
    if sender_in_reviewers_list?
      checklist = render_external_template(template_file, locals)
      update_comment(context.comment_id, checklist)
    else
      respond("@#{context.sender} I can't do that because you are not a reviewer")
    end
  end

  def sender_in_reviewers_list?
    reviewers = read_value_from_body("reviewers-list").split(",").map(&:strip)
    reviewers.include?("@#{context.sender}")
  end

  def command
    params[:command] || "generate my checklist"
  end

  def description
    "Adds a checklist for the reviewer using this command"
  end

  def example_invocation
    "@#{bot_name} #{command}"
  end
end
