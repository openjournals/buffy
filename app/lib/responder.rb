require_relative 'actions'
require_relative 'authorizations'
require_relative 'defaults'
require_relative 'github'
require_relative 'templating'
require_relative 'workers'

class Responder
  include Actions
  include Authorizations
  include Defaults
  include GitHub
  include Templating

  attr_accessor :event_regex
  attr_accessor :event_action
  attr_accessor :params
  attr_accessor :teams
  attr_accessor :services
  attr_accessor :bot_name
  attr_accessor :match_data
  attr_accessor :context


  def initialize(settings, params)
    settings = default_settings.merge(settings)
    @teams = settings[:teams]
    @services = settings[:services]
    @bot_name = settings[:bot_github_user]
    @params = params || {}
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
    @context = buffy_context
    if authorized?(buffy_context)
      process_message(message)
    else
      respond "I'm sorry @#{buffy_context.sender}, I'm afraid I can't do that. That's something only #{authorized_teams_sentence} are allowed to do."
      false
    end
  end

  # Checks if command is set via settings.
  # If needed and it's not present raises an error
  def command
    if params[:command].nil? || params[:command].strip.empty?
      raise "Configuration Error in #{self.class.name}: No value for command."
    else
      @command ||= params[:command].strip
    end
    @command
  end

  # Create a hash with the basic config info
  # and adds any data from the body issue requested via :data_from_issue param
  def locals
    from_context = { issue_id: context.issue_id,
                     repo: context.repo,
                     sender: context.sender,
                     bot_name: bot_name }
    from_body = {}
    if params[:data_from_issue].is_a? Array
      params[:data_from_issue].each do |varname|
        from_body[varname] = read_from_body("<!--#{varname}-->", "<!--end-#{varname}-->")
      end
    end

    from_context.merge from_body
  end

  # True if the responder is configured as hidden
  def hidden?
    @params[:hidden] == true
  end

  # To be overwritten by subclasses with events and actions they respond to
  def define_listening
  end

  # To be overwritten by subclasses
  def process_message(message)
  end

end
