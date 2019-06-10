class AnnoyingResponder < Responder
  def initialize
    @event_action = nil
    @event_regex = /.*/
  end

  def call(message, context)
    return false unless responds_on?(context)
    if event_regex
      "Yo!" if message.match(event_regex)
    else
      "Yo!"
    end
  end
end
