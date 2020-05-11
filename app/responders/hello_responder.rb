require_relative '../lib/responder'

class HelloResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\AHello @#{@bot_name}\z/i
  end

  def process_message(message)
    respond("Hi!")
  end
end
