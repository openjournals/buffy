require 'rugged'
require 'linguist'
require 'licensee'

class RepoChecksWorker < BuffyWorker

  AVAILABLE_CHECKS = ["repo summary", "languages", "wordcount", "license", "statement of need"]

  def perform(locals, url, branch, checks)
    load_context_and_env(locals)
    return unless setup_local_repo(url, branch)

    if checks.nil? || checks.empty?
      perform_checks = AVAILABLE_CHECKS
    else
      checks = checks.map {|c| c.strip.downcase}
      perform_checks = checks & AVAILABLE_CHECKS
    end

    repo_summary if perform_checks.include?("repo summary")
    detect_languages if perform_checks.include?("languages")
    count_words if perform_checks.include?("wordcount")
    detect_license if perform_checks.include?("license")
    detect_statement_of_need if perform_checks.include?("statement of need")

    cleanup
  end

  def repo_summary
    message = "```\nSoftware report:\n"

    cloc_result = run_cloc(path)

    if cloc_result
      message << "#{cloc_result}"
    else
      message << "cloc failed to run analysis of the source code"
    end

    message << "\n```"

    respond(message)
  end

  def detect_languages
    repo = Rugged::Repository.new(path)
    project = Linguist::Repository.new(repo, repo.head.target_id)
    ordered_languages = project.languages.sort_by { |_, size| size }.reverse
    top_3 = ordered_languages.first(3).map {|l,s| l}
    label_issue(top_3) unless top_3.empty?
  end

  def count_words
    return if paper_file.paper_path.nil?

    word_count = Open3.capture3("cat #{paper_file.paper_path} | wc -w")[0].to_i

    respond("Wordcount for `#{File.basename(paper_file.paper_path)}` is #{word_count}")
  end

  def detect_license
    license = Licensee.project(path).license
    respond("Failed to discover a valid open source license") if license.nil?
  end

  def detect_statement_of_need
    unless paper_file.text =~ /# Statement of Need/i
      respond("Failed to discover a `Statement of need` section in paper")
    end
  end

  def paper_file
    @paper_file ||= PaperFile.find(path)
  end

end
