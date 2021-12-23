require_relative '../lib/responder'

class ExternalServiceResponder < Responder

  keyname :external_service

  def define_listening
    required_params :name, :command, :url

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\.?\s*\z/i
  end

  def process_message(message)
    respond(params[:message]) if params[:message]
    ExternalServiceWorker.perform_async(params, locals)
  end

  def description
    params[:description] || "Calls external service"
  end

  def example_invocation
    params[:example_invocation] || "@#{bot_name} #{command}"
  end
end
