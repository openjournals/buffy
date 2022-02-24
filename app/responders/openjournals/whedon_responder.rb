require_relative '../../lib/responder'

module Openjournals
  class WhedonResponder < Responder
    keyname :whedon

    def define_listening
      @event_action = "issue_comment.created"
      @event_regex = /\A@whedon /i
    end

    def process_message(message)
      respond "My name is now @#{bot_name}"
    end

    def default_description
      "My name is not Whedon"
    end

    def default_example_invocation
      "@whedon whatever"
    end

    def hidden?
      true
    end
  end
end
