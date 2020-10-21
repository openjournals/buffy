module Actions

  # Create a new comment in the issue.
  def respond(message)
    bg_respond(message)
  end

  # Update the body of the issue between marks
  def update_body(start_mark, end_mark, new_text)
    new_body = issue_body.gsub(/#{start_mark}.*#{end_mark}/im, "#{start_mark}#{new_text}#{end_mark}")
    update_issue({ body: new_body })
  end

  # Add text at the end of the body of the issue
  def append_to_body(text)
    new_body = issue_body + text
    update_issue({ body: new_body })
  end

  # Remove a block of text from the body of the issue optionally including start/end marks
  def delete_from_body(start_mark, end_mark, delete_marks=false)
    if delete_marks
      new_body = issue_body.gsub(/#{start_mark}.*#{end_mark}/im, "")
    else
      new_body = issue_body.gsub(/#{start_mark}.*#{end_mark}/im, "#{start_mark}#{end_mark}")
    end
    update_issue({ body: new_body })
  end

  # Invite a user to collaborate in the repo
  def invite_user(username)
    pending_msg = "The reviewer already has a pending invitation.\n\n#{username} please accept the invite here: #{invitations_url}"
    collaborator_msg = "#{username} already has access."
    added_msg = "OK, invitation sent!\n\n#{username} please accept the invite here: #{invitations_url}"
    error_msg = "It was not possible to invite #{username}"

    return pending_msg if is_invited? username
    return collaborator_msg if is_collaborator? username
    return added_msg if add_collaborator username
    return error_msg
  end

  def read_from_body(start_mark, end_mark)
    text = ""
    issue_body.match(/#{start_mark}(.*)#{end_mark}/im) do |m|
      text = m[1]
    end
    text.strip
  end

  def replace_assignee(old_assignee, new_assignee)
    remove_assignee old_assignee unless old_assignee.nil? || old_assignee.empty?
    add_assignee new_assignee unless new_assignee.nil? || new_assignee.empty?
  end

end
