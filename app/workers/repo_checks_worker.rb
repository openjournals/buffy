require 'rugged'
require 'linguist'
require 'licensee'

class RepoChecksWorker < BuffyWorker

  AVAILABLE_CHECKS = ["repo summary", "languages", "wordcount", "license", "statement of need", "first commit date", "repo dump check"]

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
    detect_first_commit_date if perform_checks.include?("first commit date")
    detect_repo_dump if perform_checks.include?("repo dump check")

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

  def detect_first_commit_date
    repo = Rugged::Repository.new(path)
    walker = Rugged::Walker.new(repo)
    walker.push(repo.head.target_id)

    first_commit = nil
    walker.each do |commit|
      first_commit = commit
    end

    if first_commit
      commit_date = first_commit.time.strftime("%B %d, %Y")
      respond("First public commit was made on #{commit_date}")
    else
      respond("Could not determine first commit date")
    end
  end

  def detect_repo_dump
    # Analyzes commit history to detect "repo dumps" - instances where a large
    # percentage of code was added in a short time window, which may indicate
    # code was developed privately then dumped into a public repository

    repo = Rugged::Repository.new(path)
    walker = Rugged::Walker.new(repo)
    walker.push(repo.head.target_id)

    # Collect all commits with their LOC changes
    commits_data = []
    total_additions = 0

    walker.each do |commit|
      next if commit.parents.empty? # Skip initial commit (no parent to diff against)

      parent = commit.parents.first
      diff = parent.diff(commit)
      additions = diff.stat[0] # Number of lines added

      commits_data << {
        time: commit.time,
        additions: additions,
        sha: commit.oid[0..7]
      }
      total_additions += additions
    end

    return respond("No commit data available for repo dump analysis") if commits_data.empty? || total_additions == 0

    # Sort commits chronologically
    commits_data.sort_by! { |c| c[:time] }

    # Find the maximum LOC added in any rolling 48-hour window
    max_window_additions = 0
    max_window_percentage = 0.0
    window_duration = 48 * 60 * 60 # 48 hours in seconds

    commits_data.each_with_index do |commit, i|
      window_start = commit[:time]
      window_end = window_start + window_duration

      # Sum all additions within this 48-hour window
      window_additions = commits_data[i..-1]
        .take_while { |c| c[:time] <= window_end }
        .sum { |c| c[:additions] }

      if window_additions > max_window_additions
        max_window_additions = window_additions
        max_window_percentage = (window_additions.to_f / total_additions * 100).round(2)
      end
    end

    # Build response with tiered warnings based on percentage thresholds
    message = "**Commit & LOC Distribution:**\n"
    message << "- Total commits analyzed: #{commits_data.size}\n"
    message << "- Total lines added: #{total_additions}\n"
    message << "- Maximum in 48-hour window: #{max_window_additions} lines (#{max_window_percentage}%)\n"

    # Tiered warning system for repo dump signals
    if max_window_percentage >= 75
      message << "- 🚨 **Critical repo dump signal:** ≥75% of code added in 48-hour window"
    elsif max_window_percentage >= 50
      message << "- ⚠️ **Strong repo dump signal:** ≥50% of code added in 48-hour window"
    elsif max_window_percentage >= 25
      message << "- ⚡ **Moderate repo dump signal:** ≥25% of code added in 48-hour window"
    else
      message << "- ✓ Healthy distribution: <25% of code added in any 48-hour window"
    end

    respond(message)
  end

  def paper_file
    @paper_file ||= PaperFile.find(path)
  end

end
