require_relative '../lib/responder'

class CheckZenodoDoiResponder < Responder

  keyname :check_zenodo_doi

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} check zenodo doi(?:\s+(\S+))?\s*$/i
  end

  def process_message(message)
    doi = match_data && match_data[1]

    if doi.to_s.empty?
      respond("Please give the Zenodo DOI to check, for example: `@#{bot_name} check zenodo doi 10.5281/zenodo.123456`")
    else
      react_to_comment("eyes")
      ZenodoDoiWorker.perform_async(serializable(locals), doi)
    end
  end

  def default_description
    "Check that a Zenodo DOI is a version DOI (a concept DOI fails)"
  end

  def default_example_invocation
    "@#{bot_name} check zenodo doi 10.5281/zenodo.123456"
  end
end
