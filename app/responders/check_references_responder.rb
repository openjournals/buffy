require_relative '../lib/responder'

class CheckReferencesResponder < Responder

  keyname :check_references

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} check references(?: from branch ([\/\w-]+))?\.?\s*\z/i
  end

  def process_message(message)
    if target_repo_value.empty?
      respond("I couldn't find the URL for the target repository")
    else
      DOIWorker.perform_async(locals, target_repo_value, branch_name_value)
    end
  end

  def default_description
    "Check the references of the paper for missing DOIs" + "\n" +
    "# Optionally, it can be run on a non-default branch "
  end

  def default_example_invocation
    "@#{bot_name} check references" + "\n" +
    "@#{bot_name} check references from branch custom-branch-name"
  end
end
