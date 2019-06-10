class WelcomeResponder < Responder
  def initialize
    @event_action = "issues.opened"
    @event_regex = nil
  end

  def call(message, context)
    return false unless responds_on?(context)
    if event_regex
      respond("Hi!", context) if message.match(event_regex)
    else
      respond("Hi!", context)
    end
  end
end
