class AsyncMessageWorker < BuffyWorker

  def perform(locals, message, only_if_open=true)
    load_context_and_env(locals)

    return false if issue.state == "closed" && only_if_open
    return false if message.to_s.strip == ""

    respond(message)
  end
end
