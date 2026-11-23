require_relative '../lib/zenodo_doi_checker'

# Checks that a Zenodo DOI is a version DOI, which points to the one version of the software
# that was reviewed. A concept DOI fails: it resolves to whatever the latest version is.
class ZenodoDoiWorker < BuffyWorker

  def perform(locals, doi)
    load_context_and_env(locals)
    respond message_for(ZenodoDoiChecker.new(doi).check)
  end

  def message_for(result)
    doi = code(result[:doi])

    case result[:type]
    when :version
      message = "✅ #{doi} is a version DOI"
      message += " (version #{code(result[:version])})" if result[:version]
      message += "."
      message += " Note that there's a newer version of this record." if result[:latest] == false
      message
    when :concept
      latest = code(result[:latest_doi])
      latest += " (version #{code(result[:version])})" if result[:version]
      "❌ #{doi} is a concept DOI, not a version DOI. A concept DOI always resolves to the latest version " +
      "of the record, so it won't keep pointing to the version that was reviewed." +
      "\n\nPlease use the DOI of the reviewed version instead. The latest version's DOI is #{latest}."
    when :not_zenodo
      "❌ #{doi} isn't a Zenodo DOI. Zenodo DOIs look like `10.5281/zenodo.123456`."
    when :not_found
      "❌ I couldn't find a Zenodo record with the DOI #{doi}."
    else
      "I couldn't check #{doi} because Zenodo didn't respond as expected. Please try again later."
    end
  end

  private

  def code(value)
    "`#{value.to_s.delete('`')}`"
  end
end
