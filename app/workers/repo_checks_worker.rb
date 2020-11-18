require 'rugged'
require 'linguist'
require 'licensee'

class RepoChecksWorker < BuffyWorker

  AVAILABLE_CHECKS = ["repo summary", "languages", "license", "statement of need"]

  def perform(locals, url, branch, checks)
    load_context_and_settings(locals)
    return unless setup_local_repo(url, branch)

    if checks.nil? || checks.empty?
      perform_checks = AVAILABLE_CHECKS
    else
      checks = checks.map {|c| c.strip.downcase}
      perform_checks = checks & AVAILABLE_CHECKS
    end

    repo_summary if perform_checks.include?("repo summary")
    detect_languages if perform_checks.include?("languages")
    detect_license if perform_checks.include?("license")
    detect_statement_of_need if perform_checks.include?("statement of need")

    cleanup
  end

  def repo_summary
    message = "```\nSoftware report:\n"

    cloc_result = run_cloc(path)
    gitinspector_result = run_gitinspector(path)

    if cloc_result
      message << "#{cloc_result}"
    else
      message << "cloc failed to run analysis of the source code"
    end
    message << "\n\n"

    if gitinspector_result
      message << "#{gitinspector_result}"
    else
      message << "gitinspector failed to run statistical information for the repository"
    end
    message << "\n```"

    respond(message)
  end

  def detect_languages
    repo = Rugged::Repository.new(path)
    project = Linguist::Repository.new(repo, repo.head.target_id)

    top_3 = project.languages.keys.take(3)
    label_issue(top_3) unless top_3.empty?
  end

  def detect_license
    license = Licensee.project(path).license
    respond("Failed to discover a valid open source license") if license.nil?
  end

  def detect_statement_of_need
    unless PaperFile.find(path).text =~ /# Statement of Need/i
      respond("Failed to discover a `Statement of need` section in paper")
    end
  end

end
