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
    mapping = params[:mapping] || {}
    ref = params[:ref] || "main"
    mapped_parameters = {}

    mapping.each_pair do |k, v|
      mapped_parameters[k] = locals.delete(v).to_s
    end

    parameters = {}.merge(inputs, mapped_parameters)

    if trigger_workflow(workflow_repo, workflow_name, parameters, ref)
      respond(params[:message]) if params[:message]
    end
  end

  def description
    params[:description] || "Runs a GitHub workflow"
  end

  def example_invocation
    "@#{bot_name} #{command}"
  end
end
