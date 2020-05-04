Dir["#{File.expand_path '../../responders', __FILE__}/**/*.rb"].sort.each { |f| require f }

class ResponderRegistry

  RESPONDER_MAPPING = {
    "hello" => HelloResponder,
    "assign_reviewer_n" => AssignReviewerNResponder
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
      responder.call(message, context)
    end; nil
  end

  def add_responder(responder)
    responders << responder
  end

  # Load up the responders defined in config/settings-#{ENV}.yml
  def load_responders!
    config[:responders].each_pair do |name, params|
      add_responder(RESPONDER_MAPPING[name].new(config, params))
    end
  end
end
