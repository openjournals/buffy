require_relative '../lib/responder'

class HelloResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\AHello @#{@bot_name}/i
  end

  def call(message, context)
    return false unless responds_on?(context)
    if event_regex
      respond("Hi!", context) if message.match(event_regex)
    end
  end
end
