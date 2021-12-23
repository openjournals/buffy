require_relative 'logging'
Dir["#{File.expand_path '../../responders', __FILE__}/**/*.rb"].sort.each { |f| require f }

class ResponderRegistry
  include Logging

  attr_accessor :responders
  attr_accessor :config
  attr_reader   :responders_map


  def initialize(config)
    @responders_map = ResponderRegistry.available_responders
    @responders ||= Array.new
    @config = config
    load_responders!
  end

  def respond(message, context)
    responders.each do |responder|
      begin
        responder.call(message, context)
      rescue => err
        log_error(responder, err)
      end
    end; nil
  end

  def add_responder(responder)
    responders << responder
  end

  # Load up the responders defined in config/settings-#{ENV}.yml
  def load_responders!
    config[:teams] = Responder.get_team_ids(config) if config[:teams]
    config[:responders].each_pair do |name, params|
      params = {} if params.nil?
      if params.is_a?(Array)
        params.each do |responder_instances|
          responder_instances.each_pair do |instance_name, subparams|
            subparams = {} if subparams.nil?
            add_responder(@responders_map[name].new(config, Sinatra::IndifferentHash[name: instance_name.to_s].merge(subparams)))
          end
        end
      else
        add_responder(@responders_map[name].new(config, params))
      end
    end
  end

  # Create a map of all the classes in the files located in the /responders dir
  def self.available_responders
    available_responders = {}
    responder_files = Dir["#{File.expand_path '../../responders', __FILE__}/**/*.rb"].map do |f|
      f.match(/.*app\/responders\/(.*).rb/)[1]
    end

    responder_files = responder_files.compact.sort
    responder_classes = responder_files.map do |path|
      path.split("/").map do |subpath|
        subpath.split('_').each(&:capitalize!).join
      end.join('::')
    end

    responder_classes.each do |name|
      begin
        responder_class = Object.const_get(name)
        available_responders[responder_class.key] = responder_class
      rescue NameError => err
        logger.warn("There is a mismatch in a Responder class name/module: #{err.message}")
      end
    end

    available_responders
  end

  # Get an instance of one of the responders in the configuration
  def self.get_responder(config={}, responder_key=nil, responder_name=nil)
    return nil if config.empty?
    return nil if responder_key.nil?
    return nil unless config[:responders].keys.include?(responder_key)

    key = nil
    responder_params = config[:responders][responder_key] || {}

    if responder_name && responder_params.is_a?(Array)
      if responder_instance = responder_params.select {|r| r.keys.first.to_s == responder_name.to_s}.first
        key = responder_key
        params = responder_instance[responder_name] || {}
        params = Sinatra::IndifferentHash[name: responder_name.to_s].merge(params)
      end
    elsif responder_name.nil? && responder_params.is_a?(Hash)
      key = responder_key
      params = responder_params
    end

    return key.nil? ? nil : ResponderRegistry.available_responders[key].new(config, params)
  end

  def log_error(responder, error)
    logger.warn("Error calling #{responder.class}: #{error.message}")
  end
end
