require_relative "../lib/responder"

class SetValueResponder < Responder

  keyname :set_value

  def define_listening
    required_params :name

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} set (.*) as #{name}\.?\s*\z/i
  end

  def process_message(message)
    mark = "<!--#{name}-->"
    end_mark = "<!--end-#{name}-->"

    new_value = @match_data[1]
    reply = "Done! #{name} is now #{new_value}"

    case params[:if_missing].to_s.downcase
    when "append"
      update_or_add_value(name, new_value, append: true, heading: params[:heading])
    when "prepend"
      update_or_add_value(name, new_value, append: false, heading: params[:heading])
    when "error"
      unless update_value(name, new_value)
        reply = "Error: `#{name}` not found in the issue's body"
        errored = true
      end
    else
      update_body(mark, end_mark, new_value)
    end
    respond(reply)
    process_labeling unless errored
  end

  def description
    "Set a value for #{name}"
  end

  def example_invocation
    "@#{bot_name} set #{params[:sample_value] || 'xxxxx'} as #{name}"
  end

end
