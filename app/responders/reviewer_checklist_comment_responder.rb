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
      update_checklists_links
    else
      respond("@#{context.sender} I can't do that because you are not a reviewer")
    end
  end

  def sender_in_reviewers_list?
    reviewers.include?("@#{context.sender}")
  end

  def update_checklists_links
    if issue_body_has?("checklist-comments")
      mapping = checklists_mapping.merge({"#{context.sender}" => "📝 [Checklist for @#{context.sender}](#{comment_url})"})

      checklists = mapping.keys.map do |k|
        "<!--checklist-for-#{k}-->\n#{mapping[k]}\n<!--end-checklist-for-#{k}-->"
      end

      update_value("checklist-comments", "\n#{checklists.join('\n')}\n")
    end
  end

  def reviewers
    @reviewers ||= read_value_from_body("reviewers-list").split(",").map(&:strip)
  end

  def checklists_mapping
    mapping = {}
    reviewers.each do |rev|
      rev_login = rev.gsub("@", "")
      checklink_link = read_value_from_body("checklist-for-rev_login")
      mapping[rev_login] = checklink_link unless checklink_link.empty?
    end
    mapping
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
