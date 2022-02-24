require_relative '../lib/responder'

class GoodbyeResponder < Responder

  keyname :goodbye

  def define_listening
    @event_action = "issues.closed"
    @event_regex = nil
  end

  def process_message(message)
    respond(params[:message]) if params[:message]
    if params[:messages].is_a?(Array)
      params[:messages].each {|msg| respond(msg)}
    end

    respond_external_template(params[:template_file], locals) if params[:template_file]

    external_service(params[:external_service]) if params[:external_service]

    process_labeling
  end

  def external_service(service_params)
    check_required_params(service_params)
    process_external_service(service_params, locals)
  end

  def check_required_params(service_params)
    [:name, :url].each do |param_name|
      if service_params[param_name].nil? || service_params[param_name].strip.empty?
        raise "Configuration Error in GoodbyeResponder: No value for #{param_name}."
      end
    end
  end

  def default_description
    "Runs after an issue is closed"
  end

  def default_example_invocation
    "Is invoked once, when an issue is closed"
  end

  def hidden?
    true
  end
end
