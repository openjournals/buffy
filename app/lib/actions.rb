module Actions

  # Create a new comment in the issue.
  def respond(message)
    bg_respond(message)
  end

  # Update the body of the issue between marks
  def update_body(start_mark, end_mark, new_text)
    new_body = issue.body.gsub(/#{start_mark}(.*)#{end_mark}/i, "#{start_mark}#{new_text}#{end_mark}")
    update_issue({ body: new_body })
  end

  # Invite a user to collaborate in the repo
  def invite_user(username)
    username = username.sub(/^@/, "").downcase

    pending_msg = "The reviewer already has a pending invitation.\n\n@#{username} please accept the invite here: #{invitations_url}"
    collaborator_msg = "@#{username} already has access."
    added_msg = "OK, invitation sent!\n\n@#{username} please accept the invite here: #{invitations_url}"

    return pending_msg if is_invited? username
    return collaborator_msg if is_collaborator? username

    add_collaborator username
    return added_msg
  end

end
