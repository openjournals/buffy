require 'bibtex'
require 'faraday'
require 'serrano'

class DOIChecker

  def initialize(entries=[])
    @entries = entries
  end

  def check_dois
    doi_summary = {ok: [], missing: [], invalid: []}

    if @entries.any?
      @entries.each do |entry|
        if entry.has_field?('doi') && !entry.doi.empty?
          doi_validity = validate_doi(entry.doi.value)
          doi_summary[doi_validity[:validity]].push(doi_validity[:msg])
        # If there's no DOI present, check Crossref to see if we can find a candidate DOI for this entry.
        elsif entry.has_field?('title')
            candidate_doi = crossref_lookup(entry.title.value)
            if candidate_doi == "CROSSREF-ERROR"
              truncated_title = entry.title.to_s[0,50]
              truncated_title += "..." if truncated_title.length < entry.title.to_s.length
              doi_summary[:missing].push("Errored finding suggestions for \"#{truncated_title}\", please try later")
            elsif candidate_doi
              doi_summary[:missing].push("#{candidate_doi} may be a valid DOI for title: #{entry.title}")
            end
        end
      end
    end

    doi_summary
  end

  def validate_doi(doi_string)
    return { validity: :invalid, msg: "Empty DOI string" } if doi_string.nil? || doi_string.empty?

    if doi_string.include?('http')
      return { validity: :invalid, msg: "#{doi_string} is INVALID because of 'https://doi.org/' prefix" }
    end

    if doi_string.include?('doi.org/')
      return { validity: :invalid, msg: "#{doi_string} is INVALID because of 'doi.org/' prefix" }
    end

    begin
      doi_string.gsub!(/[^a-zA-z0-9:;<>\.\(\)\/\-_]/, "")
      escaped_doi_string = doi_string.gsub("<", "%3C").gsub(">", "%3E").gsub("[", "%5B").gsub("]", "%5D")

      doi_url = URI.join("https://doi.org", escaped_doi_string).to_s

      status_code = Faraday.head(doi_url).status
      return { validity: :ok, msg: "#{doi_string} is OK" } if [301, 302].include? status_code
      return { validity: :invalid, msg: "#{doi_string} is INVALID" }
    rescue Faraday::ConnectionFailed
      return { validity: :invalid, msg: "#{doi_string} is INVALID (failed connection)" }
    rescue URI::InvalidURIError
      return { validity: :invalid, msg: "#{doi_string} URL is INVALID" }
    end
  end

  def crossref_lookup(title)
    works = Serrano.works(query: title)
    if works['message'].any? && works['message']['items'].any?
      if works['message']['items'].first.has_key?('DOI')
        candidate = works['message']['items'].first
        return nil unless candidate['title']

        candidate_title = candidate['title'].first.downcase
        candidate_doi = candidate['DOI']
        return candidate_doi if similar?(candidate_title, title.downcase)
      end
    end
    nil
  rescue Serrano::InternalServerError, Serrano::GatewayTimeout, Serrano::BadGateway, Serrano::ServiceUnavailable
    return "CROSSREF-ERROR"
  end

  # How different are two strings?
  # https://en.wikipedia.org/wiki/Levenshtein_distance
  def levenshtein_distance(s, t)
    m = s.length
    n = t.length

    return m if n == 0
    return n if m == 0
    d = Array.new(m+1) {Array.new(n+1)}

    (0..m).each {|i| d[i][0] = i}
    (0..n).each {|j| d[0][j] = j}
    (1..n).each do |j|
      (1..m).each do |i|
        d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
                    d[i-1][j-1]       # no operation required
                  else
                    [ d[i-1][j]+1,    # deletion
                      d[i][j-1]+1,    # insertion
                      d[i-1][j-1]+1,  # substitution
                    ].min
                  end
      end
    end

    d[m][n]
  end

  def similar?(string_1, string_2)
    levenshtein_distance(string_1, string_2) < 3
  end
end
