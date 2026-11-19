require 'json'
require_relative '../lib/authors_checker'

class AuthorsCheckWorker < BuffyWorker

  MAX_CONTRIBUTORS = 50

  # A Zenodo DOI (10.5281/zenodo.123, also inside a doi.org link) or a zenodo.org record URL.
  # The record id is in the first or the second group. Sandbox records are not matched.
  ZENODO_REFERENCE = %r{10\.5281/zenodo\.(\d+)|(?<![\w.-])zenodo\.org/(?:records?|uploads|deposit)/(\d+)}i

  # Raised when it's not clear which archive should be checked
  class ArchiveConflict < StandardError; end

  # archive_sources: { "command" => archive given in the command, "issue" => archive value in the
  # issue's body, "field" => name of the archive field (as in "@bot set <value> as <field>") }
  def perform(locals, url, branch, archive_sources, ignored_logins)
    load_context_and_env(locals)
    notes = []
    archive = find_archive(archive_sources.to_h, notes)

    paper, error = paper_file_from_repo(url, branch)
    return respond(error) if error

    paper_authors = paper.authors
    return respond("I couldn't find a list of authors in the paper's metadata.") if paper_authors.empty?

    zenodo_creators = zenodo_creators_for(archive, notes)
    github_contributors = github_contributors_for(url, notes)

    checker = AuthorsChecker.new(paper_authors: paper_authors,
                                 zenodo_creators: zenodo_creators,
                                 github_contributors: github_contributors,
                                 ignored_logins: ignored_logins.to_a)

    respond_template :authors_check, { report: checker.check, notes: notes }
  rescue ArchiveConflict => e
    respond(e.message)
  ensure
    cleanup
  end

  # Only the paper's metadata is needed, so instead of downloading the whole repository
  # this clones it without file contents and fetches just the metadata file (paper.md,
  # or paper.yml for LaTeX papers). Nothing from the repository is written to disk.
  # Returns [PaperFile, nil], or [nil, error message].
  def paper_file_from_repo(url, branch)
    unless clone_repo_metadata(url, path, branch)
      return [nil, "Downloading the repository failed. Please make sure the URL and the branch name are correct."]
    end

    # If there are several papers, use the one closest to the root of the repository
    paper_path = repo_files(path).select { |f| f.match?(/(\A|\/)paper\.(md|tex)\z/) }.min_by { |f| [f.count("/"), f] }
    if paper_path.nil?
      return [nil, "I couldn't find a `paper.md` or `paper.tex` file in the repository, so I can't check the authors."]
    end

    metadata_path = paper_path.end_with?(".tex") ? File.join(File.dirname(paper_path), "paper.yml") : paper_path
    content = read_repo_file(path, metadata_path)
    if content.nil?
      return [nil, "I couldn't read #{inline_code(metadata_path)} from the repository, so I can't check the authors."]
    end

    paper = PaperFile.new(utf8(paper_path))
    paper.metadata_content = content
    [paper, nil]
  end

  # Finds the archive to check, in this order:
  #   1. the archive given in the command
  #   2. the archive value in the issue's body
  #   3. the most recent comment mentioning a Zenodo DOI or URL
  # If the most recent "@bot set <value> as archive" command doesn't match the archive in the
  # issue (e.g. because that command was refused), it's not clear which one is right, so
  # ArchiveConflict is raised to ask the editor to set it. The bot's own comments are skipped
  # (they can mention Zenodo DOIs of cited software, e.g. in reference checks).
  # Returns "" if no archive is found.
  def find_archive(sources, notes)
    value = ->(v) { v = v.to_s.strip; v.casecmp?("pending") ? "" : v }

    archive = value.call(sources["command"])
    return archive unless archive.empty?

    field = sources["field"].to_s.strip.empty? ? "archive" : sources["field"].to_s.strip
    issue_archive = value.call(sources["issue"])

    set_command = /\A@#{Regexp.escape(context.bot_name.to_s)} set (.*) as #{Regexp.escape(field)}\.?\s*$/i
    set_comment = human_comments.find { |c| c.body.to_s.match?(set_command) }
    set_archive = set_comment ? value.call(set_comment.body[set_command, 1]) : ""
    if !set_archive.empty? && !set_archive.casecmp?(issue_archive)
      in_issue = issue_archive.empty? ? "the issue has no #{field} set" : "the issue has #{inline_code(issue_archive)}"
      raise ArchiveConflict, "I can't tell which archive to check: the most recent " +
                             "`@#{context.bot_name} set ... as #{field}` command ([this comment](#{comment_url(set_comment.id)})) " +
                             "sets #{inline_code(set_archive)}, but #{in_issue}. This usually means that command didn't go through. " +
                             "Please set the right archive in the issue with `@#{context.bot_name} set <DOI> as #{field}` and try again."
    end
    return issue_archive unless issue_archive.empty?

    human_comments.each do |comment|
      references = []
      comment.body.to_s.scan(ZENODO_REFERENCE) { references << Regexp.last_match[0] }
      next if references.empty?

      # The last reference in a comment is usually the newest ("old: ..., new: ...")
      archive = references.last
      notes << "Using the Zenodo archive #{inline_code(archive)} mentioned in [this comment](#{comment_url(comment.id)})."
      return archive
    end

    ""
  end

  # Issue comments not written by the bot, most recent first
  def human_comments
    @human_comments ||= begin
      bot = context.bot_name.to_s.downcase
      github_client.issue_comments(context.repo, context.issue_id).reverse.reject { |c| c.user&.login.to_s.downcase == bot }
    rescue Octokit::Error, Faraday::Error => e
      logger.warn("Error reading comments of issue #{context.issue_id}: #{e.message}")
      []
    end
  end

  # Returns the list of creators of the Zenodo archive, or nil if they can't be retrieved
  def zenodo_creators_for(archive, notes)
    archive = archive.to_s.strip

    if archive.empty?
      notes << "I couldn't find a Zenodo archive in the command, the issue or its comments, so Zenodo authors were not checked. " +
               "To check them, run `@#{context.bot_name} check authors with archive <Zenodo DOI or URL>`."
      return nil
    end

    match = archive.match(ZENODO_REFERENCE)
    if match.nil?
      kind = archive.match?(/sandbox\.zenodo\.org/i) ? "is a Zenodo sandbox record" : "is not a Zenodo DOI or URL"
      notes << "The archive (#{inline_code(archive)}) #{kind}, so its authors were not checked."
      return nil
    end

    record = zenodo_record(match[1] || match[2])
    if record.nil?
      notes << "I couldn't retrieve the Zenodo record for #{inline_code(archive)}, so Zenodo authors were not checked."
      return nil
    end

    creators = record.dig("metadata", "creators").to_a
    creators.map { |c| { name: c["name"].to_s, orcid: c["orcid"].to_s } }
  end

  def zenodo_record(record_id)
    url = "https://zenodo.org/api/records/#{record_id}"
    3.times do
      response = Faraday.get(url, nil, { "Accept" => "application/json" })
      if [301, 302, 303, 307, 308].include?(response.status) && response.headers["location"]
        url = URI.join(url, response.headers["location"]).to_s
        next
      end
      return response.status == 200 ? JSON.parse(response.body) : nil
    end
    nil
  rescue Faraday::Error, JSON::ParserError, URI::Error
    nil
  end

  # Returns the list of GitHub contributors of the repo, or nil if they can't be retrieved
  def github_contributors_for(url, notes)
    repo_name = url.to_s.strip[%r{\Ahttps?://(?:www\.)?github\.com/([\w.-]+/[\w.-]+?)(?:\.git)?/?\z}i, 1]
    if repo_name.nil?
      notes << "The repository is not hosted on GitHub, so GitHub contributors were not checked."
      return nil
    end

    contributors = github_client.contributors(repo_name).reject { |c| c[:type] == "Bot" || c[:login].to_s.end_with?("[bot]") }

    if contributors.size > MAX_CONTRIBUTORS
      notes << "This repository has #{contributors.size} contributors; only the #{MAX_CONTRIBUTORS} with the most commits were checked."
      contributors = contributors.first(MAX_CONTRIBUTORS)
    end

    failed_lookups = 0
    result = contributors.map do |c|
      name = begin
        get_user(c[:login])&.name.to_s.strip
      rescue Octokit::Error, Faraday::Error => e
        logger.warn("Error getting GitHub user #{c[:login]}: #{e.message}")
        failed_lookups += 1
        ""
      end
      { login: c[:login], name: name, contributions: c[:contributions] }
    end

    if failed_lookups > 0
      notes << "I couldn't look up the GitHub profile of #{failed_lookups} contributor#{failed_lookups == 1 ? "" : "s"}, " +
               "so they were matched by username only."
    end

    result
  rescue Octokit::Error, Faraday::Error => e
    logger.warn("Error getting contributors for #{repo_name}: #{e.message}")
    notes << "I couldn't retrieve the list of contributors from GitHub, so GitHub contributors were not checked."
    nil
  end

  private

  # Text inside a code span on one line, so it can't break out of it and mention anyone
  def inline_code(text)
    "`#{utf8(text).tr("`", "'").gsub(/[[:space:]]+/, " ").strip}`"
  end

  def utf8(text)
    text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
  end
end
