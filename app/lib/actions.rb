module Actions

  # Create a new comment in the issue.
  def respond(message)
    bg_respond(message)
  end

  # Update the body of the issue between marks
  def update_body(start_mark, end_mark, new_text)
    @issue_body = issue_body.gsub(/#{start_mark}.*#{end_mark}/im, "#{start_mark}#{new_text}#{end_mark}")
    update_issue({ body: @issue_body })
  end

  # Add text at the end of the body of the issue
  def append_to_body(text)
    @issue_body = issue_body + text
    update_issue({ body: @issue_body })
  end

  # Add text at the beginning of the body of the issue
  def prepend_to_body(text)
    @issue_body = text + issue_body
    update_issue({ body: @issue_body })
  end

  # Update the body of the issue with the new text
  def new_body(text)
    @issue_body = text
    update_issue({ body: @issue_body })
  end

  # Remove a block of text from the body of the issue optionally including start/end marks
  def delete_from_body(start_mark, end_mark, delete_marks=false)
    if delete_marks
      @issue_body = issue_body.gsub(/#{start_mark}.*#{end_mark}/im, "")
    else
      @issue_body = issue_body.gsub(/#{start_mark}.*#{end_mark}/im, "#{start_mark}#{end_mark}")
    end
    update_issue({ body: @issue_body })
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

  # Return whether placeholder HTML comments is present in the issue's body
  def issue_body_has?(value_name)
    start_mark = "<!--#{value_name}-->"
    end_mark = "<!--end-#{value_name}-->"
    issue_body.match?(/#{start_mark}(.*)#{end_mark}/im)
  end

  # Read string in issue's body between start_mark and end_mark
  def read_from_body(start_mark, end_mark)
    text = ""
    issue_body.match(/#{start_mark}(.*)#{end_mark}/im) do |m|
      text = m[1]
    end
    text.strip
  end

  # Read value in issue's body between HTML comments
  def read_value_from_body(value_name)
    start_mark = "<!--#{value_name}-->"
    end_mark = "<!--end-#{value_name}-->"
    read_from_body(start_mark, end_mark)
  end

  # Read value in issue's body between HTML comments
  # if value name exists, otherwise use default value name
  def value_of_or_default(option_1, default_value)
    if option_1.nil? || option_1.empty?
      value_name = default_value
    else
      value_name = option_1.strip
    end
    read_value_from_body(value_name)
  end

  # Update value in issue's body, or add it if it doesn't exist
  def update_or_add_value(value_name, text, append: true, hide: false, heading: nil)
    start_mark = "<!--#{value_name}-->"
    end_mark = "<!--end-#{value_name}-->"

    if issue_body_has?(value_name)
      update_body(start_mark, end_mark, text)
    else
      if hide
        value_heading = ""
      elsif heading.nil?
        value_heading = "**#{value_name.capitalize.gsub(/[_-]/, " ")}:** "
      else
        value_heading = "**#{heading}:** "
      end

      if append
        append_to_body "\n#{value_heading}#{start_mark}#{text}#{end_mark}"
      else
        prepend_to_body "#{value_heading}#{start_mark}#{text}#{end_mark}\n"
      end
    end
  end

  # Update value in issue's body between HTML comments
  def update_value(value_name, text)
    found = issue_body_has?(value_name)
    if found
      start_mark = "<!--#{value_name}-->"
      end_mark = "<!--end-#{value_name}-->"
      update_body(start_mark, end_mark, text)
    end
    found
  end

  # Update list in issue's body between HTML comments
  def update_list(list_name, text)
    update_value("#{list_name}-list", text)
  end

  # Replace an assigned user from the assignees list of the issue
  def replace_assignee(old_assignee, new_assignee)
    remove_assignee old_assignee unless old_assignee.nil? || old_assignee.empty?
    add_assignee new_assignee unless new_assignee.nil? || new_assignee.empty?
  end

end
