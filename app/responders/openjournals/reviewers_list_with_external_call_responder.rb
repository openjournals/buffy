require_relative '../../lib/responder'
require 'faraday'
require 'json'

module Openjournals
  class ReviewersListWithExternalCallResponder < Responder

    keyname :openjournals_reviewers_list

    def define_listening
      @event_action = "issue_comment.created"
      @event_regex = /\A@#{bot_name} (add|remove) (\S+) (to reviewers|from reviewers|as reviewer)\.?\s*$/i
    end

    def process_message(message)
      add_or_remove = @match_data[1].downcase
      new_reviewer = @match_data[2].strip
      to_or_from = @match_data[3].downcase

      if !issue_body_has?("reviewers-list")
        respond("I can't find the reviewers list")
        return
      end

      unless username?(new_reviewer) || new_reviewer == "me"
        respond("I can't add that reviewer: #{new_reviewer} is not a username")
        return
      end

      new_reviewer = "@#{context.sender}" if new_reviewer == "me"

      add_to_or_remove_from = [add_or_remove, to_or_from].join(" ")

      if ["add to reviewers", "add as reviewer"].include?(add_to_or_remove_from)
        add new_reviewer
      elsif ["remove from reviewers", "remove as reviewer"].include?(add_to_or_remove_from)
        remove new_reviewer
      else
        respond("That command is confusing. Did you mean to ADD TO REVIEWERS or to REMOVE FROM REVIEWERS?")
      end
    end

    def add(new_reviewer)
      if list_of_reviewers.include?(new_reviewer)
        respond("#{new_reviewer} is already included in the reviewers list")
      else
        new_list = (list_of_reviewers + [new_reviewer]).uniq.join(", ")
        update_value("reviewers-list", new_list)
        respond("#{new_reviewer} added to the reviewers list!")
        add_collaborator(new_reviewer) if add_as_collaborator?(new_reviewer)
        add_assignee(new_reviewer) if add_as_assignee?(new_reviewer)
        process_labeling if list_of_reviewers.empty?
        api_call_review_assignment(new_reviewer)
      end
    end

    def remove(reviewer)
      if list_of_reviewers.include?(reviewer)
        new_list = (list_of_reviewers - [reviewer])
        new_value = new_list.empty? ? no_reviewers_text : new_list.uniq.join(", ")

        update_value("reviewers-list", new_value)
        respond("#{reviewer} removed from the reviewers list!")
        remove_assignee(reviewer) if add_as_assignee?(reviewer)
        process_reverse_labeling if new_list.empty?
        api_call_review_unassignment(reviewer)
      else
        respond("#{reviewer} is not in the reviewers list")
      end
    end

    def list_of_reviewers
      @list_of_reviewers ||= read_value_from_body("reviewers-list").split(",").map(&:strip) - no_reviewers_texts
    end

    def no_reviewers_text
      @no_reviewers_text ||= (params[:no_reviewers_text] || 'Pending').strip
    end

    def no_reviewers_texts
      [no_reviewers_text, no_reviewers_text.upcase, no_reviewers_text.downcase]
    end

    def add_as_collaborator?(value)
      username?(value) && params[:add_as_collaborator] == true
    end

    def add_as_assignee?(value)
      username?(value) && params[:add_as_assignee] == true
    end

    def default_description
      ["Add to this issue's reviewers list",
       "Remove from this issue's reviewers list"]
    end

    def api_call_review_assignment(reviewer)
      return nil if env[:reviewers_host_url].to_s.empty?
      return nil unless Regexp.new("^\\[REVIEW\\]:").match?(context.issue_title)

      url = "#{env[:reviewers_host_url]}/api/stats/update/#{reviewer}/review_assigned"
      idempotency_key = "assign-#{reviewer}-#{context.issue_id}"

      response = Faraday.post(url, { idempotency_key: idempotency_key }, { "TOKEN" => env[:reviewers_api_token] })

      if response.status.between?(400, 599)
        logger.warn("Error assigning review #{context.issue_id} to #{reviewer}: Got response code #{response.status}")
      end
    end

    def api_call_review_unassignment(reviewer)
      return nil if env[:reviewers_host_url].to_s.empty?
      return nil unless Regexp.new("^\\[REVIEW\\]:").match?(context.issue_title)

      url = "#{env[:reviewers_host_url]}/api/stats/update/#{reviewer}/review_unassigned"
      idempotency_key = "assign-#{reviewer}-#{context.issue_id}"

      response = Faraday.post(url, { idempotency_key: idempotency_key }, { "TOKEN" => env[:reviewers_api_token] })

      if response.status.between?(400, 599)
        logger.warn("Error unassigning #{reviewer} from review #{context.issue_id}: Got response code #{response.status}")
      end
    end

    def default_example_invocation
      ["@#{bot_name} add #{params[:sample_value] || '@username'} as reviewer",
       "@#{bot_name} remove #{params[:sample_value] || '@username'} from reviewers"]
    end
  end
end
