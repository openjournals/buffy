require_relative '../../lib/responder'
require 'faraday'
require 'json'

module Openjournals
  class PingTrackEicsResponder < Responder
    keyname :ping_track_eics

    def define_listening
      @event_action = "issue_comment.created"
      @event_regex = /\A@#{bot_name} ping track[ -]eics?\.?\s*$/i
    end

    def process_message(message)
      eics_teams_suffix = params[:eics_teams_suffix] || "-eics"
      eics_team = params[:default_eics_team] || "openjournals/joss-eics"
      host = params[:journal_base_url] || "https://joss.theoj.org"

      track_lookup = Faraday.get("#{host}/papers/#{context.issue_id}/lookup_track" )
      if track_lookup.status == 200
        track_name = JSON.parse(track_lookup.body, symbolize_names: true)[:parameterized]
        eics_team = "openjournals/#{track_name}#{eics_teams_suffix}" unless track_name.nil?
      end
      eics_team.sub!(/^@/, "")

      respond ":bellhop_bell::exclamation:Hey @#{eics_team}, this submission requires your attention."
    end

    def default_description
      "Mention the EiCs for the correct track"
    end

    def default_example_invocation
      "@#{bot_name} ping track-eic"
    end
  end
end
