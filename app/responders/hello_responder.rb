require_relative '../lib/responder'

class HelloResponder < Responder

  keyname :hello

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A(Hello|Hi) @#{bot_name}[\.!]?\s*$/i
  end

  def process_message(message)
    respond("Hi!")
  end

  def default_description
    "Say hi!"
  end

  def default_example_invocation
    "Hello @#{bot_name}"
  end
end
