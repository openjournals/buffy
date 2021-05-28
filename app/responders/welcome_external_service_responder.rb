require_relative '../lib/responder'

class WelcomeExternalServiceResponder < Responder

  keyname :welcome_external_service

  def define_listening
    required_params :name, :url

    @event_action = "issues.opened"
    @event_regex = nil
  end

  def process_message(message)
    respond(params[:message]) if params[:message]
    ExternalServiceWorker.perform_async(params, locals)
  end

  def description
    params[:description] || "Calls external service after an issue is opened"
  end

  def example_invocation
    "Is invoked when an issue is created"
  end

  def hidden?
    true
  end
end
