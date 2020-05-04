require_relative 'github'

class Responder
  include GitHub

  attr_accessor :event_regex
  attr_accessor :event_action
  attr_accessor :params
  attr_accessor :teams
  attr_accessor :bot_name
  attr_accessor :match_data


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
    @match_data = event_regex.match(message)
    return @match_data
  end

  def call(message, context)
    return false unless responds_on?(context)
    return false unless responds_to?(message)
    @context = context
    process_message(message, @context)
  end

  # Post a message to GitHub.
  def respond(message, context)
    bg_respond(message, context)
  end

  # To be overwritten by subclasses with events and actions they respond to
  def define_listening
  end

  # To be overwritten by subclasses
  def process_message(message, context)
  end

end
