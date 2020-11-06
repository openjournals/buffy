require_relative '../lib/responder'

class CheckReferencesResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} check references(?: from branch ([\w-]*))?\s*\z/i
  end

  def process_message(message)
    if url.empty?
      respond("I couldn't find the target repo value")
    else
      DOIWorker.perform_async(locals, url, branch)
    end
  end

  def branch
    mark = "<!--branch-value-->"
    end_mark = "<!--end-branch-value-->"
    branch_in_body = read_from_body(mark, end_mark)

    if @match_data.nil? || @match_data[1].nil?
      branch_in_command = nil
    else
      branch_in_command = @match_data[1]
    end

    [branch_in_command, branch_in_body].compact.select {|s| !s.strip.empty? }.first
  end

  def url
    mark = "<!--target-repository-->"
    end_mark = "<!--end-target-repository-->"
    @target_repo_url ||= read_from_body(mark, end_mark)
  end

  def description
    "Check the references of the paper for missing DOIs" + "\n" +
    "# Optionally, it can be run on a non-default branch "
  end

  def example_invocation
    "@#{@bot_name} check references" + "\n" +
    "@#{@bot_name} check references from custom-branch-name"
  end
end
