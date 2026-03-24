require_relative '../lib/responder'

class InviteResponder < Responder

  keyname :invite

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} invite ([@\w-]+(?:,\s*[@\w-]+)*)\.?\s*$/i
  end

  def process_message(message)
    @match_data[1].split(",").map(&:strip).uniq.each do |username|
      reply = invite_user username
      respond reply if reply
    end
  end

  def default_description
    "Send an invitation to a user to collaborate in the review"
  end

  def default_example_invocation
    "@#{bot_name} invite @username"
  end
end
