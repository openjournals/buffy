require_relative '../lib/responder'

class ExternalServiceResponder < Responder

  def define_listening
    required_params :service

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{command}\s*\z/i
  end

  def process_message(message)
    respond(params[:message]) if params[:message]
    ExternalServiceWorker.perform_async(@service, locals)
  end

  def description
    params[:description] || "Calls external service"
  end

  def example_invocation
    "@#{@bot_name} #{command}"
  end
end
