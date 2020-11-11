require_relative '../lib/responder'

class WelcomeResponder < Responder

  def define_listening
    @event_action = "issues.opened"
    @event_regex = nil
  end

  def process_message(message)
    respond(reply)
    process_labeling
  end

  def description
    "Send a message after an issue is opened"
  end

  def example_invocation
    "Is invoked once, when an issue is created"
  end

  def reply
    params[:reply] || "Hi!, I'm @#{bot_name}, a friendly bot.\n\nType ```@#{bot_name} help``` to discover how I can help you."
  end

  def hidden?
    true
  end
end
