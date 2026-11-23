require 'faraday'
require 'json'

# Finds out whether a Zenodo DOI is a version DOI (one specific version of a record) or a
# concept DOI (all versions of a record, always resolving to the latest one).
#
# Zenodo's API answers a request for a version's record id with that record, and a request
# for a concept's record id with a redirect to the record of its latest version. Every
# record lists both its own DOI and its concept DOI.
#
# #check returns a hash with a :type and, depending on it, more details:
#   :version    => doi:, concept_doi: (nil if it has none), version:, latest: (true/false/nil)
#   :concept    => doi:, latest_doi:, version: (of the latest version)
#   :not_zenodo => doi:  (the value isn't a Zenodo DOI)
#   :not_found  => doi:  (no Zenodo record has that DOI)
#   :error      => doi:  (Zenodo couldn't be reached or gave an unexpected answer)
class ZenodoDoiChecker
  ZENODO_DOI = %r{\A10\.5281/zenodo\.(\d+)\z}i
  API_URL = "https://zenodo.org/api/records"

  attr_reader :doi

  def initialize(doi)
    @doi = normalize(doi)
  end

  def check
    record_id = doi.match(ZENODO_DOI)&.captures&.first
    return result(:not_zenodo) unless record_id

    response = get("#{API_URL}/#{record_id}")

    case response.status
    when 200
      from_record(parse(response.body))
    when 301, 302, 303, 307, 308
      latest = get(URI.join(API_URL, response.headers["location"].to_s).to_s)
      latest.status == 200 ? from_concept_redirect(record_id, parse(latest.body)) : result(:error)
    when 404, 410
      result(:not_found)
    else
      result(:error)
    end
  rescue Faraday::Error, JSON::ParserError, URI::Error, ArgumentError
    result(:error)
  end

  private

  # Accepts a bare DOI or one written as "doi:..." or as a doi.org link.
  def normalize(value)
    value.to_s.strip
         .sub(%r{\Ahttps?://(dx\.)?doi\.org/}i, "")
         .sub(/\Adoi:\s*/i, "")
         .sub(/[.,;]+\z/, "")
  end

  def get(url)
    connection.get(url, nil, { "Accept" => "application/json" })
  end

  def connection
    @connection ||= Faraday.new(request: { open_timeout: 10, timeout: 20 })
  end

  def parse(body)
    JSON.parse(body)
  end

  # The record id was a record's own id: it's a version DOI if that record's DOI is this one.
  # (Records imported with a DOI from somewhere else have a Zenodo id but no Zenodo DOI.)
  def from_record(record)
    if same_doi?(record["doi"], doi)
      result(:version, concept_doi: record["conceptdoi"],
                       version: record.dig("metadata", "version"),
                       latest: latest?(record))
    elsif same_doi?(record["conceptdoi"], doi)
      result(:concept, latest_doi: record["doi"], version: record.dig("metadata", "version"))
    else
      result(:not_found)
    end
  end

  # The record id redirected to another record: it's a concept DOI if this is the concept's id
  # and it has been registered as a DOI.
  def from_concept_redirect(record_id, latest_record)
    if latest_record["conceptrecid"].to_s == record_id && same_doi?(latest_record["conceptdoi"], doi)
      result(:concept, latest_doi: latest_record["doi"], version: latest_record.dig("metadata", "version"))
    else
      result(:not_found)
    end
  end

  def latest?(record)
    is_last = record.dig("metadata", "relations", "version", 0, "is_last")
    is_last.nil? ? nil : is_last == true
  end

  def same_doi?(a, b)
    !a.to_s.empty? && a.to_s.casecmp?(b.to_s)
  end

  def result(type, details = {})
    { type: type, doi: doi }.merge(details)
  end
end
