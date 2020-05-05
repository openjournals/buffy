module Authorizations

  def authorized_team_ids(params)
    @authorized_team_ids ||= begin
      teams_ids = []
      case params[:only]
      when String
        teams_ids << @teams[params[:only]]
      when Array
        params[:only].each { |team_name| teams_ids << @teams[team_name] }
      end
      teams_ids
    end
  end

  def authorized_team_names(params)
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
    if authorized_team_names.size = 1
      authorized_team_names[0]
    elsif authorized_team_names.size > 1
      "#{authorized_team_names[0...-1] * ', '} and #{authorized_team_names[-1]}"
    else
      ""
    end
  end

end
