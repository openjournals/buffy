require_relative 'github'

class Responder
  include GitHub

  attr_accessor :event_regex
  attr_accessor :event_action
  attr_accessor :params
  attr_accessor :teams
  attr_accessor :bot_name


  def initialize(settings, params)
    @teams = settings[:teams]
    @bot_name = settings[:bot_github_user]
    @params = params
    @settings = settings
    define_listening
  end

  # Does the responder responder to this kind of event?
  # Returns true if no event_action is set (e.g. nil)
  # otherwise checks if the responder.event_action is the same as the
  # webhook event_action
  def responds_on?(context)
    return true unless event_action
    context.event_action == event_action ? true : false
  end

  # Does the responder respond to this message?
  # Returns true if the event_regex is nil
  # otherwise check if the message matches the responder regex
  def responds_to?(message)
    return true unless event_regex
    message.match(event_regex)
  end

  # Post a message to GitHub.
  def respond(message, context)
    bg_respond(message, context)
  end

  # To be overwritten by subclasses with events and actions they respond to
  def define_listening
  end
end
