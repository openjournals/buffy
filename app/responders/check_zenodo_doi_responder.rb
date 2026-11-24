require_relative '../lib/responder'
require_relative '../lib/zenodo_doi_checker'

class CheckZenodoDoiResponder < Responder

  keyname :check_zenodo_doi

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} check zenodo doi(?:\s+(\S+))?\s*$/i
  end

  # When another responder runs this one (e.g. after setting the archive), only Zenodo DOIs are
  # checked: anything else is fine and gets no reply at all.
  def process_message(message)
    doi = match_data && match_data[1]
    return if run_by_other_responder && !ZenodoDoiChecker.zenodo_doi?(doi)

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
