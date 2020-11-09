require_relative '../lib/responder'

class CheckReferencesResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} check references(?: from branch ([\w-]+))?\s*\z/i
  end

  def process_message(message)
    if url.empty?
      respond("I couldn't find URL for the target repository")
    else
      DOIWorker.perform_async(locals, url, branch)
    end
  end

  def branch
    if params[:branch_field].nil? || params[:branch_field].empty?
      branch_field = "branch"
    else
      branch_field = params[:branch_field].strip
    end
    mark = "<!--#{branch_field}-->"
    end_mark = "<!--end-#{branch_field}-->"

    if @match_data.nil? || @match_data[1].nil?
      branch_name = read_from_body(mark, end_mark)
    else
      branch_name = @match_data[1]
    end

    branch_name.empty? ? nil : branch_name
  end

  def url
    if params[:url_field].nil? || params[:url_field].empty?
      url_field = "target-repository"
    else
      url_field = params[:url_field].strip
    end
    mark = "<!--#{url_field}-->"
    end_mark = "<!--end-#{url_field}-->"
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
