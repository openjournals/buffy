require_relative '../lib/responder'

class AddAndRemoveAssigneeResponder < Responder

  keyname :add_remove_assignee

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} (add|remove) assignee: ([@\w-]+)\.?\s*$/i
  end

  def process_message(message)
    add_or_remove = @match_data[1].downcase
    user = @match_data[2]

    if ["add", "assign"].include?(add_or_remove)
      add user
    elsif add_or_remove == "remove"
      remove user
    end
  end

  def add(user)
    if can_be_assignee?(user)
      add_assignee(user)
      respond("#{user} added as assignee.")
      process_labeling
    else
      respond("#{user} lacks permissions to be an assignee.")
    end
  end

  def remove(user)
    remove_assignee(user)
    respond("#{user} removed from assignees.")
    process_reverse_labeling
  end

  def default_description
    ["Add a user to this issue's assignees list",
     "Remove a user from this issue's assignees list"]
  end

  def default_example_invocation
    ["@#{bot_name} add assignee: @username",
     "@#{bot_name} remove assignee: @username"]
  end
end
