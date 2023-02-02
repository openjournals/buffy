require_relative '../../lib/responder'
require 'ojra'

module Openjournals
  class ReviewersLogReviewEndResponder < Responder

    keyname :openjournals_reviewers_end_review

    def define_listening
      @event_action = "issues.closed"
      @event_regex = nil
    end

    def process_message(message)
      if Regexp.new("^\\[REVIEW\\]:").match?(context.issue_title)
        client = OJRA::Client.new(env[:reviewers_host_url], env[:reviewers_api_token])
        client.unassign_reviewers(list_of_reviewers, context.issue_id)
      end

    rescue OJRA::Error => e
      logger.warn("Error unassigning reviewers from issue #{context.issue_id}: #{e.message}")
    end

    def list_of_reviewers
      read_value_from_body("reviewers-list").split(",").map(&:strip)
    end

    def default_description
      "Logs a review end for each or the reviewers"
    end

    def default_example_invocation
      "Is invoked once, when an review issue is closed"
    end

    def hidden?
      true
    end
  end
end
