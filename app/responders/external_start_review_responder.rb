require_relative "../lib/responder"

class ExternalStartReviewResponder < Responder

  keyname :external_start_review

  def define_listening
    required_params :external_call

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} start review\.?\s*\z/i
  end

  def process_message(message)
    return unless roles_and_issue?
    process_external_service(params[:external_call], locals_with_editor_and_reviewers)
  end

  def roles_and_issue?
    unless username?(reviewers_usernames.first.to_s)
      respond("Can't start a review without reviewers")
      return false
    end

    unless username?(editor_username)
      respond("Can't start a review without an editor")
      return false
    end

    if context.issue_title.match(title_regex)
      respond("Can't start a review when the review has already started")
      return false
    end

    true
  end

  def reviewers_usernames
    @reviewers_usernames ||= read_value_from_body("reviewers-list").split(",").map(&:strip)
  end

  def reviewers_logins
    @reviewers_logins ||= reviewers_usernames.map {|reviewer_username| user_login(reviewer_username)}.join(",")
  end

  def editor_username
    @editor_username ||= read_value_from_body("editor")
  end

  def editor_login
    @editor_login ||= user_login(editor_username)
  end

  def title_regex
    params[:review_title_regex] || /^\[REVIEW\]:/
  end

  def locals_with_editor_and_reviewers
    locals.merge({ reviewers_usernames: reviewers_usernames,
                   reviewers_logins: reviewers_logins,
                   editor_username: editor_username,
                   editor_login: editor_login })
  end

  def description
    "Open the review issue"
  end

  def example_invocation
    "@#{@bot_name} start review"
  end
end

