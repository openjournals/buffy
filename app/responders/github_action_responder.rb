require_relative '../lib/responder'

class GithubActionResponder < Responder

  keyname :github_action

  def define_listening
    required_params :workflow_repo, :workflow_name, :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\.?\s*\z/i
  end

  def process_message(message)
    inputs = params[:inputs] || {}
    inputs_from_issue = params[:data_from_issue] || []
    mapping = params[:mapping] || {}
    ref = params[:workflow_ref] || "main"
    mapped_parameters = {}

    inputs_from_issue.each do |input_from_issue|
      mapped_parameters[input_from_issue] = locals[input_from_issue].to_s
    end

    mapping.each_pair do |k, v|
      mapped_parameters[k] = locals[v].to_s
      mapped_parameters.delete(v)
    end

    parameters = {}.merge(inputs, mapped_parameters)

    if trigger_workflow(workflow_repo, workflow_name, parameters, ref)
      respond(params[:message]) if params[:message]
      process_labeling
    end
  end

  def default_description
    "Runs a GitHub workflow"
  end

  def default_example_invocation
    "@#{bot_name} #{command}"
  end
end
