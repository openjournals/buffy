require_relative '../lib/responder'

class WelcomeTemplateResponder < Responder

  def define_listening
    @event_action = "issues.opened"
    @event_regex = nil
  end

  def process_message(message)
    respond_external_template template_file, locals
  end

  def description
    "Send a message using a template after an issue is opened"
  end

  def example_invocation
    "Is invoked once, when an issue is created"
  end

  def template_file
    if params[:template_file].nil? || params[:template_file].strip.empty?
      raise "Configuration Error in WelcomeTemplateResponder: No value for template_file."
    else
      @template_file ||= params[:template_file].strip
    end
    @template_file
  end

  def hidden?
    true
  end
end
