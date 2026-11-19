require_relative '../lib/responder'

class AuthorsCheckResponder < Responder

  keyname :authors_check

  BRANCH_OPTION = /from branch ([\/\.\w-]+)/i
  ARCHIVE_OPTION = /with archive (\S+)/i

  def define_listening
    @event_action = "issue_comment.created"
    # Optional "from branch <name>" and "with archive <DOI or URL>", in any order
    @event_regex = /\A@#{bot_name} check authors((?: +(?:from branch [\/\.\w-]+|with archive \S+))*)\.?\s*$/i
  end

  def process_message(message)
    if target_repo_value.empty?
      respond("I couldn't find the URL for the target repository")
    else
      react_to_comment("eyes")
      AuthorsCheckWorker.perform_async(serializable(locals), target_repo_value, branch_value, archive_value, ignored_logins)
    end
  end

  # The branch from the command, or else from the issue
  def branch_value
    command_option(BRANCH_OPTION) || value_of_or_default(params[:branch_field], "branch")
  end

  # The archive DOI or URL from the command, or else from the issue
  def archive_value
    command_option(ARCHIVE_OPTION)&.sub(/\.\z/, "") || value_of_or_default(params[:archive_field], "archive")
  end

  # GitHub users that should not be listed as missing authors, by default the reviewers and the editor
  def ignored_logins
    fields = params[:ignored_users_fields] || ["reviewers-list", "editor"]
    read_values_from_body(fields).select { |v| username?(v) }.map { |v| user_login(v).downcase }
  end

  def default_description
    "Compare the paper's authors with the Zenodo archive's authors and the repository's contributors" + "\n" +
    "# Optionally, it can be run on a non-default branch, or with a Zenodo archive that isn't set in the issue yet "
  end

  def default_example_invocation
    "@#{bot_name} check authors" + "\n" +
    "@#{bot_name} check authors from branch custom-branch-name" + "\n" +
    "@#{bot_name} check authors with archive https://zenodo.org/records/123456"
  end

  private

  def command_option(option_regex)
    options = @match_data && @match_data[1]
    options.to_s[option_regex, 1]
  end
end
