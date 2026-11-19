require 'json'
require_relative '../lib/authors_checker'

class AuthorsCheckWorker < BuffyWorker

  MAX_CONTRIBUTORS = 50

  # archive_sources: { "command" => archive given in the command, "issue" => archive value in the
  # issue's body, "field" => name of the archive field (as in "@bot set <value> as <field>") }
  def perform(locals, url, branch, archive_sources, ignored_logins)
    load_context_and_env(locals)
    return unless setup_local_repo(url, branch)

    paper = PaperFile.find(path)
    paper_authors = paper.authors
    notes = []

    if paper.paper_path.nil?
      respond("I couldn't find a `paper.md` or `paper.tex` file in the repository, so I can't check the authors.")
    elsif paper_authors.empty?
      respond("I couldn't find a list of authors in the paper's metadata.")
    else
      zenodo_creators = zenodo_creators_for(find_archive(archive_sources.to_h, notes), notes)
      github_contributors = github_contributors_for(url, notes)

      checker = AuthorsChecker.new(paper_authors: paper_authors,
                                   zenodo_creators: zenodo_creators,
                                   github_contributors: github_contributors,
                                   ignored_logins: ignored_logins.to_a)

      respond_template :authors_check, { report: checker.check, notes: notes }
    end

    cleanup
  end

  # A Zenodo DOI (10.5281/zenodo.123, also inside a doi.org link) or record URL (zenodo.org/records/123)
  ZENODO_REFERENCE = %r{10\.5281/zenodo\.\d+|zenodo\.org/records?/\d+}i

  # Finds the archive to check, in this order:
  #   1. the archive given in the command
  #   2. the most recent "@bot set <value> as archive" comment
  #   3. the archive value in the issue's body
  #   4. the most recent comment mentioning a Zenodo DOI or URL
  # The bot's own comments are skipped (they can mention Zenodo DOIs of cited software,
  # e.g. in reference checks). Returns "" if no archive is found.
  def find_archive(sources, notes)
    value = ->(v) { v = v.to_s.strip; v.casecmp?("pending") ? "" : v }

    archive = value.call(sources["command"])
    return archive unless archive.empty?

    field = sources["field"].to_s.empty? ? "archive" : sources["field"].to_s
    set_command = /\A@#{Regexp.escape(context.bot_name.to_s)} set (.*) as #{Regexp.escape(field)}\.?\s*$/i
    set_comment = human_comments.find { |c| !value.call(c.body.to_s[set_command, 1]).empty? }
    if set_comment
      archive = value.call(set_comment.body[set_command, 1])
      notes << "Using the archive `#{archive.tr("`", "")}` set in [this comment](#{comment_url(set_comment.id)})."
      return archive
    end

    archive = value.call(sources["issue"])
    return archive unless archive.empty?

    mention = human_comments.find { |c| c.body.to_s.match?(ZENODO_REFERENCE) }
    if mention
      archive = mention.body[ZENODO_REFERENCE]
      notes << "Using the Zenodo archive `#{archive}` mentioned in [this comment](#{comment_url(mention.id)})."
      return archive
    end

    ""
  end

  # Issue comments not written by the bot, most recent first
  def human_comments
    @human_comments ||= begin
      bot = context.bot_name.to_s.downcase
      github_client.issue_comments(context.repo, context.issue_id).reverse.reject { |c| c.user&.login.to_s.downcase == bot }
    rescue Octokit::Error => e
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

    record_id = archive[/zenodo\.(\d+)/i, 1] || archive[%r{zenodo\.org/records?/(\d+)}i, 1]
    if record_id.nil?
      notes << "The archive (`#{archive.tr("`", "")}`) is not a Zenodo DOI or URL, so its authors were not checked."
      return nil
    end

    record = zenodo_record(record_id)
    if record.nil?
      notes << "I couldn't retrieve the Zenodo record for `#{archive.tr("`", "")}`, so Zenodo authors were not checked."
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

    contributors.map do |c|
      { login: c[:login], name: get_user(c[:login])&.name.to_s.strip, contributions: c[:contributions] }
    end
  rescue Octokit::Error => e
    logger.warn("Error getting contributors for #{repo_name}: #{e.message}")
    notes << "I couldn't retrieve the list of contributors from GitHub, so GitHub contributors were not checked."
    nil
  end
end
