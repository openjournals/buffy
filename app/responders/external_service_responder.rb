require_relative '../lib/responder'

class ExternalServiceResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    respond(params[:message]) if params[:message]
    ExternalServiceWorker.perform_async(@service, locals)
  end

  def service
    if params[:service].nil? || params[:service].strip.empty?
      raise "Configuration Error in ExternalServiceResponder: No value for service."
    else
      @service = @services[params[:service].strip]
    end
    @service
  end

  def description
    params[:description] || "Calls external service"
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
