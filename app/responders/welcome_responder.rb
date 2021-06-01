require_relative '../lib/responder'

class WelcomeResponder < Responder

  keyname :welcome

  def define_listening
    @event_action = "issues.opened"
    @event_regex = nil
  end

  def process_message(message)
    respond(params[:message]) if params[:message]
    if params[:messages].is_a?(Array)
      params[:messages].each {|msg| respond(msg)}
    end

    respond_external_template(params[:template_file], locals) if params[:template_file]

    process_labeling
  end

  def description
    "Replies after an issue is opened"
  end

  def example_invocation
    "Is invoked once, when an issue is created"
  end

  def hidden?
    true
  end
end
