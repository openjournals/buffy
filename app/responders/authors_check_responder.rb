require_relative '../lib/responder'

class AuthorsCheckResponder < Responder

  keyname :authors_check

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} check authors(?: from branch ([\/\.\w-]+))?\.?\s*$/i
  end

  def process_message(message)
    if target_repo_value.empty?
      respond("I couldn't find the URL for the target repository")
    else
      react_to_comment("eyes")
      AuthorsCheckWorker.perform_async(serializable(locals), target_repo_value, branch_name_value, archive_value, ignored_logins)
    end
  end

  def archive_value
    value_of_or_default(params[:archive_field], "archive")
  end

  # GitHub users that should not be listed as missing authors, by default the reviewers and the editor
  def ignored_logins
    fields = params[:ignored_users_fields] || ["reviewers-list", "editor"]
    read_values_from_body(fields).select { |v| username?(v) }.map { |v| user_login(v).downcase }
  end

  def default_description
    "Compare the paper's authors with the Zenodo archive's authors and the repository's contributors" + "\n" +
    "# Optionally, it can be run on a non-default branch "
  end

  def default_example_invocation
    "@#{bot_name} check authors" + "\n" +
    "@#{bot_name} check authors from branch custom-branch-name"
  end
end
