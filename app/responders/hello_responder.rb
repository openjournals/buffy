require_relative '../lib/responder'

class HelloResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\AHello @#{@bot_name}/i
  end

  def process_message(message, context)
    respond("Hi!", context) if message.match(event_regex)
  end
end
