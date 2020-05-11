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

end
