require_relative 'github'
require_relative 'actions'
require_relative 'authorizations'

class Responder
  include Authorizations
  include Actions
  include GitHub

  attr_accessor :event_regex
  attr_accessor :event_action
  attr_accessor :params
  attr_accessor :teams
  attr_accessor :bot_name
  attr_accessor :match_data
  attr_accessor :context


  def initialize(settings, params)
    @teams = settings[:teams]
    @bot_name = settings[:bot_github_user]
    @params = params
    @settings = settings
    @context = nil
    define_listening
  end

  # Does the responder responder to this kind of event?
  # Returns true if no event_action is set (e.g. nil)
  # otherwise checks if the responder.event_action is the same as the
  # webhook event_action
  def responds_on?(buffy_context)
    return true unless event_action
    buffy_context.event_action == event_action ? true : false
  end

  # Does the responder respond to this message?
  # Returns true if the event_regex is nil
  # otherwise check if the message matches the responder regex
  def responds_to?(message)
    return true unless event_regex
    @match_data = event_regex.match(message)
    return @match_data
  end

  # Is the sender authorized to this action?
  # Returns true if user belongs to any authorized team
  # or if there's no list of authorized teams
  def authorized?(buffy_context)
    if params[:only].nil?
      return true
    else
      user_authorized? buffy_context.sender
    end
  end

  # If user can perform action and the responder responds to
  # this event and message then process_message is called
  def call(message, buffy_context)
    return false unless responds_on?(buffy_context)
    return false unless responds_to?(message)
    if authorized?(buffy_context)
      @context = buffy_context
      process_message(message)
    else
      respond "I'm sorry @#{buffy_context.sender}, I'm afraid I can't do that. That's something only #{authorized_teams_sentence} are allowed to do.", buffy_context
    end
  end

  # To be overwritten by subclasses with events and actions they respond to
  def define_listening
  end

  # To be overwritten by subclasses
  def process_message(message)
  end

end
