require_relative 'responder_registry'

module RespondersLoader
  def responders
    @responders ||= ResponderRegistry.new(settings.buffy)
  end
end
