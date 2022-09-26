require_relative '../lib/responder'

class RepoChecksResponder < Responder

  keyname :repo_checks

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} check repository(?: from branch ([\/\w-]+))?\.?\s*$/i
  end

  def process_message(message)
    if target_repo_value.empty?
      respond("I couldn't find the URL for the target repository")
    else
      RepoChecksWorker.perform_async(serializable(locals), target_repo_value, branch_name_value, serializable(params[:checks]))
    end
  end

  def default_description
    "Perform checks on the repository" + "\n" +
    "# Optionally, it can be run on a non-default branch "
  end

  def default_example_invocation
    "@#{bot_name} check repository" + "\n" +
    "@#{bot_name} check repository from branch custom-branch-name"
  end
end