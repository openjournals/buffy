class ResponderGroup
  attr_accessor :responders
  attr_accessor :config

  def initialize(config)
    @responders ||= Array.new
    @config = config
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
    config.each do |r|
      add_responder(Kernel.const_get(r).new)
    end
  end
end
