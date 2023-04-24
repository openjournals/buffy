require_relative '../../lib/responder'
require 'uri'
require 'faraday'


module Openjournals
  class SetArchiveResponder < Responder
    keyname :openjournals_set_archive

    def define_listening
      @event_action = "issue_comment.created"
      @event_regex = /\A@#{bot_name} set (.*) as archive\.?\s*$/i
    end

    def process_message(message)
      new_value = @match_data[1]
      new_value = new_value.gsub("https://doi.org/", "")

      ok_reply = "Done! archive is now [#{new_value}](https://doi.org/#{new_value})"
      nok_reply = "Error: `archive` not found in the issue's body"

      if valid_doi_value?(new_value)
        reply = update_value("archive", new_value) ? ok_reply : nok_reply
      else
        reply = "That doesn't look like a valid DOI value"
      end
      respond(reply)
    end

    def valid_doi_value?(archive_value)
      escaped_archive_value = archive_value.gsub("<", "%3C").gsub(">", "%3E").gsub("[", "%5B").gsub("]", "%5D")
      doi_url = URI.join("https://doi.org", escaped_archive_value).to_s

      status_code = Faraday.head(doi_url).status
      return [301, 302].include?(status_code)
    rescue
      return false
    end

    def default_description
      "Set a value for the archive DOI"
    end

    def default_example_invocation
      "@#{bot_name} set set 10.5281/zenodo.6861996 as archive"
    end
  end
end
