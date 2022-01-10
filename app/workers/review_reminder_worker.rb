class ReviewReminderWorker < BuffyWorker

  def perform(locals, human, is_author)
    load_context_and_env(locals)

    return false if issue.state == "closed"

    if is_author
      respond(":wave: #{human}, please update us on how things are progressing here (this is an automated reminder).")
    else
      respond(":wave: #{human}, please update us on how your review is going (this is an automated reminder).")
    end
  end
end
