module Authorizations

  def authorized_team_ids
    @authorized_team_ids ||= begin
      team_ids = []
      teams_ids_or_names = []
      case params[:only]
      when String
        teams_ids_or_names << @teams[params[:only]]
      when Array
        params[:only].each { |team_name| teams_ids_or_names << @teams[team_name] }
      end

      teams_ids_or_names.each do |team_id_or_name|
        case team_id_or_name
        when Integer
          team_ids << team_id_or_name
        when String
          org_team = team_id_or_name.split('/')
          raise "Configuration Error: Invalid team name: #{team_id_or_name}" unless org_team.size == 2
          team_id = team_id(org_team[0], org_team[1])
          team_ids << team_id unless team_id.nil?
        end
      end
      team_ids.uniq
    end
  end

  def authorized_team_names
    @authorized_team_names ||= begin
      team_names = []
      case params[:only]
      when String
        team_names << params[:only]
      when Array
        params[:only].each { |team_name| team_names << team_name }
      end
      team_names
    end
  end

  def authorized_teams_sentence
    @authorized_teams_sentence ||= begin
      if authorized_team_names.size == 1
        authorized_team_names[0]
      elsif authorized_team_names.size > 1
        "#{authorized_team_names[0...-1] * ', '} and #{authorized_team_names[-1]}"
      else
        ""
      end
    end
  end

end
