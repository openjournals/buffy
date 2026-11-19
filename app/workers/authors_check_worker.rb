require 'json'
require_relative '../lib/authors_checker'

class AuthorsCheckWorker < BuffyWorker

  MAX_CONTRIBUTORS = 50

  def perform(locals, url, branch, archive, ignored_logins)
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
      zenodo_creators = zenodo_creators_for(archive, notes)
      github_contributors = github_contributors_for(url, notes)

      checker = AuthorsChecker.new(paper_authors: paper_authors,
                                   zenodo_creators: zenodo_creators,
                                   github_contributors: github_contributors,
                                   ignored_logins: ignored_logins.to_a)

      respond_template :authors_check, { report: checker.check, notes: notes }
    end

    cleanup
  end

  # Returns the list of creators of the Zenodo archive, or nil if they can't be retrieved
  def zenodo_creators_for(archive, notes)
    archive = archive.to_s.strip
    record_id = archive[/zenodo\.(\d+)/i, 1]

    if archive.empty? || archive.downcase == "pending"
      notes << "No archive DOI found in this issue, so Zenodo authors were not checked."
      return nil
    elsif record_id.nil?
      notes << "The archive (`#{archive.tr("`", "")}`) is not a Zenodo DOI, so its authors were not checked."
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
