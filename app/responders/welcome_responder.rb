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

    external_service(params[:external_service]) if params[:external_service]

    if params[:check_references] && !target_repo_value.empty?
      DOIWorker.perform_async(locals, target_repo_value, branch_name_value)
    end

    if params[:repo_checks] && !target_repo_value.empty?
      checks = params[:repo_checks].is_a?(Hash) ? params[:repo_checks][:checks] : nil
      RepoChecksWorker.perform_async(locals, target_repo_value, branch_name_value, checks)
    end

    process_labeling
  end

  def external_service(service_params)
    check_required_params(service_params)
    locals_with_issue_data = get_data_from_issue(service_params[:data_from_issue]).merge(locals)

    ExternalServiceWorker.perform_async(service_params, locals_with_issue_data)
  end

  def check_required_params(service_params)
    [:name, :url].each do |param_name|
      if service_params[param_name].nil? || service_params[param_name].strip.empty?
        raise "Configuration Error in WelcomeResponder: No value for #{param_name}."
      end
    end
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
