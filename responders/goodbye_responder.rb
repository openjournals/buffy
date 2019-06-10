class GoodbyeResponder < Responder
  def initialize
    @event_action = "issues.closed"
    @event_regex = nil
  end

  def call(message, context)
    return false unless responds_on?(context)
    if event_regex
      "See ya!" if message.match(event_regex)
    else
      "See ya!"
    end
  end
end
