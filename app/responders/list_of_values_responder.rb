require_relative '../lib/responder'

class ListOfValuesResponder < Responder

  keyname :list_of_values

  def define_listening
    required_params :name

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} (add|remove) (\S+) (to|from) #{name}\.?\s*$/i
  end

  def process_message(message)
    add_or_remove = @match_data[1].downcase
    value = @match_data[2]
    to_or_from = @match_data[3].downcase

    if !issue_body_has?("#{name}-list")
      respond("I can't find the #{name} list")
      return
    end

    add_to_or_remove_from = [add_or_remove, to_or_from].join(" ")

    if add_to_or_remove_from == "add to"
      add value
    elsif add_to_or_remove_from == "remove from"
      remove value
    else
      respond("That command is confusing. Did you mean to ADD TO #{name} or to REMOVE FROM #{name}?")
    end
  end

  def add(value)
    if list_of_values.include?(value)
      respond("#{value} is already included in the #{name} list")
    else
      new_list = (list_of_values + [value]).uniq.join(", ")
      update_list(name, new_list)
      respond("#{value} added to the #{name} list!")
      add_collaborator(value) if add_as_collaborator?(value)
      add_assignee(value) if add_as_assignee?(value)
      process_labeling if list_of_values.empty?
    end
  end

  def remove(value)
    if list_of_values.include?(value)
      new_list = (list_of_values - [value]).uniq.join(", ")
      update_list(name, new_list)
      respond("#{value} removed from the #{name} list!")
      remove_assignee(value) if add_as_assignee?(value)
      process_reverse_labeling if new_list.empty?
    else
      respond("#{value} is not in the #{name} list")
    end
  end

  def list_of_values
    @list_of_values ||= read_value_from_body("#{name}-list").split(",").map(&:strip)
  end

  def add_as_collaborator?(value)
    username?(value) && params[:add_as_collaborator] == true
  end

  def add_as_assignee?(value)
    username?(value) && params[:add_as_assignee] == true
  end

  def default_description
    ["Add to this issue's #{name} list",
     "Remove from this issue's #{name} list"]
  end

  def default_example_invocation
    ["@#{bot_name} add #{params[:sample_value] || 'xxxxx'} to #{name}",
     "@#{bot_name} remove #{params[:sample_value] || 'xxxxx'} from #{name}"]
  end
end
