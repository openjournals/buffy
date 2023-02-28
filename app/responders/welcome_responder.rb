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
      DOIWorker.perform_async(serializable(locals), target_repo_value, branch_name_value)
    end

    if params[:repo_checks] && !target_repo_value.empty?
      checks = params[:repo_checks].is_a?(Hash) ? params[:repo_checks][:checks] : nil
      RepoChecksWorker.perform_async(serializable(locals), target_repo_value, branch_name_value, checks)
    end

    if params[:run_responder]
      if params[:run_responder].is_a?(Array)
        params[:run_responder].each do |other_responder|
          other_responder.each_pair do |other_responder_name, other_responder_params|
            process_other_responder(other_responder_params)
          end
        end
      else
        process_other_responder(params[:run_responder])
      end
    end

    close_issue if params[:close] == true

    process_labeling
  end

  def external_service(service_params)
    check_required_params(service_params)
    process_external_service(service_params, locals)
  end

  def check_required_params(service_params)
    [:name, :url].each do |param_name|
      if service_params[param_name].nil? || service_params[param_name].strip.empty?
        raise "Configuration Error in WelcomeResponder: No value for #{param_name}."
      end
    end
  end

  def default_description
    "Replies after an issue is opened"
  end

  def default_example_invocation
    "Is invoked once, when an issue is created"
  end

  def hidden?
    true
  end
end
