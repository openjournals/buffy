require_relative '../lib/responder'

class WelcomeResponder < Responder

  def define_listening
    @event_action = "issues.opened"
    @event_regex = nil
  end

  def process_message(message)
    respond(reply)
  end

  def description
    "Send a message after a issue is opened"
  end

  def example_invocation
    "Is invoked once, when a issue is created"
  end

  def reply
    params[:reply] || "You are welcome"
  end

  def hidden?
    true
  end
end
