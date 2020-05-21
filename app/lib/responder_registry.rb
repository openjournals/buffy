require 'logger'
Dir["#{File.expand_path '../../responders', __FILE__}/**/*.rb"].sort.each { |f| require f }

class ResponderRegistry

  RESPONDER_MAPPING = {
    "help"              => HelpResponder,
    "hello"             => HelloResponder,
    "assign_reviewer_n" => AssignReviewerNResponder,
    "remove_reviewer_n" => RemoveReviewerNResponder,
    "assign_editor"     => AssignEditorResponder,
    "remove_editor"     => RemoveEditorResponder,
    "set_value"         => SetValueResponder,
    "thanks"            => ThanksResponder,
  }

  attr_accessor :responders
  attr_accessor :config

  def initialize(config)
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
    config[:responders].each_pair do |name, params|
      params = {} if params.nil?
      if params.is_a?(Array)
        params.each do |responder_instances|
          responder_instances.each_pair do |instance_name, subparams|
            subparams = {} if subparams.nil?
            add_responder(RESPONDER_MAPPING[name].new(config, Sinatra::IndifferentHash[name: instance_name.to_s].merge(subparams)))
          end
        end
      else
        add_responder(RESPONDER_MAPPING[name].new(config, params))
      end
    end
  end

  def log_error(responder, error)
    logger.warn("Error calling #{responder.class}: #{error.message}")
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end
end
