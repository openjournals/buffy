require_relative 'actions'
require_relative 'authorizations'
require_relative 'defaults'
require_relative 'github'
require_relative 'templating'
require_relative 'workers'
require_relative 'logging'

class Responder
  include Actions
  include Authorizations
  include Defaults
  include GitHub
  include Templating
  include Logging

  attr_accessor :event_regex
  attr_accessor :event_action
  attr_accessor :params
  attr_accessor :teams
  attr_accessor :env
  attr_accessor :bot_name
  attr_accessor :match_data
  attr_accessor :context

  def self.keyname(key)
    @key = key.to_s
  end

  def self.key
    @key || self.name
  end


  def initialize(settings, params)
    settings[:env] = default_settings.merge(settings[:env] || {})
    @settings = settings
    @env = @settings[:env]
    @teams = settings[:teams]
    @params = params || {}
    @bot_name = @env[:bot_github_user]
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
    role_nil = params[:authorized_roles_in_issue].nil?
    only_nil = params[:only].nil?

    return true if (role_nil && only_nil)

    if !role_nil
      authorized_users_in_issue = read_values_from_body([params[:authorized_roles_in_issue]].flatten)
      return true if authorized_users_in_issue.include?("@#{buffy_context.sender}")
    end

    if !only_nil
      return user_authorized?(buffy_context.sender)
    end

    false
  end

  # Check conditions set in the config file
  # Returns true if all conditions are met
  # or there's no conditions. False otherwise.
  def meet_conditions?
    return true if params[:if].nil? || params[:if].empty?
    title_condition = params[:if][:title].nil? ? "" : params[:if][:title]
    body_condition = params[:if][:body].nil? ? "" : params[:if][:body]
    value_condition = params[:if][:value_exists].nil? ? "" : params[:if][:value_exists]
    role_assigned_condition = params[:if][:role_assigned].nil? ? "" : params[:if][:role_assigned]
    value_matches_condition = params[:if][:value_matches].nil? ? {} : params[:if][:value_matches]
    labels_condition = params[:if][:labels].nil? ? [] : [params[:if][:labels]].flatten
    rejection_response = params[:if][:reject_msg].nil? ? "" : params[:if][:reject_msg]

    unless title_condition.empty? || Regexp.new(title_condition).match?(@context.issue_title)
      respond(rejection_response) unless rejection_response.empty?
      return false
    end

    unless body_condition.empty? || Regexp.new(body_condition).match?(@context.issue_body)
      respond(rejection_response) unless rejection_response.empty?
      return false
    end

    unless value_condition.empty? || !read_value_from_body(value_condition).empty?
      respond(rejection_response) unless rejection_response.empty?
      return false
    end

    unless role_assigned_condition.empty? || username?(read_value_from_body(role_assigned_condition))
      respond(rejection_response) unless rejection_response.empty?
      return false
    end

    if value_matches_condition.is_a?(Hash)
      value_matches_condition.each_pair do |k, v|
        unless Regexp.new(v.to_s.strip).match?(read_value_from_body(k))
          respond(rejection_response) unless rejection_response.empty?
          return false
        end
      end
    else
      raise "Configuration Error in #{self.class.name}: value_matches should be a hash of [field_name:expected_value] pairs"
    end

    unless labels_condition.all? {|l| @context.issue_labels.map{|il| il["name"]}.include?(l)}
      respond(rejection_response) unless rejection_response.empty?
      return false
    end

    return true
  end

  # If user can perform action
  # and the responder responds to this event and message
  # and all conditions from settings are met
  # then process_message is called
  def call(message, buffy_context)
    return false unless responds_on?(buffy_context)
    return false unless responds_to?(message)
    @context = buffy_context
    if authorized?(buffy_context)
      process_message(message) if meet_conditions?
    else
      respond "I'm sorry @#{buffy_context.sender}, I'm afraid I can't do that. That's something only #{authorized_teams_and_roles_sentence} are allowed to do."
    end
    true
  end

  # Check required params
  # Raise an error if any of them is missing
  # Create an reader method for each param name
  def required_params(*param_names)
    param_names.each do |param_name|
      param_name = param_name.to_sym
      if empty_param?(param_name)
        raise "Configuration Error in #{self.class.name}: No value for #{param_name}."
      else
        self.class.define_method(param_name.to_s) { params[param_name] }
      end
    end
  end

  # True if param's value is empty
  def empty_param?(x)
    return true if params[x].nil?
    if params[x].is_a?(Hash) || params[x].is_a?(Array)
      params[x].empty?
    else
      params[x].to_s.strip.empty?
    end
  end

  # Create a hash with the basic config info
  # and adds any data from the body issue requested via :data_from_issue param
  def locals
    from_command = get_data_from_command_regex
    from_context = Sinatra::IndifferentHash[
                     issue_id: context.issue_id,
                     issue_author: context.issue_author,
                     issue_title: context.issue_title,
                     repo: context.repo,
                     sender: context.sender,
                     bot_name: bot_name ]
    from_body = get_data_from_issue(params[:data_from_issue])

    from_command.merge(from_body, from_context)
  end

  # Create a hash with the data from the body issue listed in the source array
  def get_data_from_issue(values_list)
    body_issue_data = Sinatra::IndifferentHash.new
    if values_list.is_a? Array
      values_list.each do |varname|
        body_issue_data[varname] = read_value_from_body(varname)
      end
    end
    body_issue_data
  end

  def get_data_from_command_regex
    command_regex_data = Sinatra::IndifferentHash.new
    if @match_data && @match_data.size > 1
      (1..@match_data.size-1).each { |i| command_regex_data["match_data_#{i}"] = @match_data[i] }
    end
    command_regex_data
  end

  # Create background workers to perform external calls
  def process_external_service(service_config, service_data)
    unless service_config.nil? || service_config.empty?
      service_locals = get_data_from_issue(service_config[:data_from_issue]).merge(service_data)
      ExternalServiceWorker.perform_async(serializable(service_config), serializable(service_locals))
    end
  end

  # Call a different responder bypassing authorization
  def process_other_responder(other_responder={})
    matching_responder = ResponderRegistry.get_responder(@settings, other_responder[:responder_key], other_responder[:responder_name])

    if matching_responder
      matching_responder.context = context
      msg = other_responder[:message] || ""
      matching_responder.match_data = matching_responder.event_regex.match(msg) unless msg.empty?
      matching_responder.process_message(msg)
    end
  end

  def serializable(info)
    if info.is_a?(Hash)
      serializable_data = {}
      info.each_pair {|k, v| serializable_data[k.to_s] = serializable(v)}
    elsif info.is_a?(Array)
      serializable_data = []
      info.each{|item| serializable_data << serializable(item)}
    elsif info.is_a?(Time) || info.is_a?(Date)
      serializable_data = info.to_s
    else
      serializable_data = info
    end

    serializable_data
  end

  # Add/remove labels as configured in the responder' settings
  def process_labeling
    process_adding_labels
    process_removing_labels
  end

  # Add labels if :add_labels is present in the responder' settings
  def process_adding_labels
    label_issue(labels_to_add) unless labels_to_add.empty?
  end

  # Remove labels if :remove_labels is present in the responder' settings
  def process_removing_labels
    unless labels_to_remove.empty?
      (labels_to_remove & issue_labels).each {|label| unlabel_issue(label)}
    end
  end

  # Read the :add_labels setting for this responder
  def labels_to_add
    if params[:add_labels].nil? || !params[:add_labels].is_a?(Array) || params[:add_labels].uniq.compact.empty?
      @labels_to_add ||= []
    end

    @labels_to_add ||= params[:add_labels].uniq.compact
  end

  # Read the :remove_labels setting for this responder
  def labels_to_remove
    if params[:remove_labels].nil? || !params[:remove_labels].is_a?(Array) || params[:remove_labels].uniq.compact.empty?
      @labels_to_remove ||= []
    end

    @labels_to_remove ||= params[:remove_labels].uniq.compact
  end

  # Process labels in reverse to undo a labeling action
  # It will add the :remove_labels and remove the :add_labels
  def process_reverse_labeling
    removed = labels_to_remove
    added = labels_to_add

    @labels_to_remove = added
    @labels_to_add = removed

    process_labeling
  end

  # Finds the value of the url of the target-repository in the body of the issue
  # by default reads the field called "target-repository"
  # unless a diferent name is set using param :url_field
  def target_repo_value
    @target_repo_url ||= value_of_or_default(params[:url_field], "target-repository")
  end

  # Finds the name of the branch in the body of the issue
  # by default reads the field called "branch"
  # unless a diferent name is set using param :branch_field
  # or if it comes in the match_data in the specified position
  def branch_name_value(branch_index=1)
    if @match_data.nil? || @match_data[branch_index].nil?
      branch_name = value_of_or_default(params[:branch_field], 'branch')
    else
      branch_name = @match_data[branch_index]
    end
  end

  # True if the responder is configured as hidden
  def hidden?
    params[:hidden] == true
  end

  # Default description can be overriden by config param
  def description
    params[:description] || default_description
  end

  # Default example_invocation can be overriden by config param
  def example_invocation
    params[:example_invocation] || default_example_invocation
  end

  # To be overwritten by subclasses with settings needed and events/actions they respond to
  def define_listening
  end

  # To be overwritten by subclasses
  def process_message(message)
  end

end
