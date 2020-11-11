require_relative "../lib/responder"

class SetValueResponder < Responder

  def define_listening
    required_params :name

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} set (.*) as #{name}\s*\z/i
  end

  def process_message(message)
    mark = "<!--#{name}-->"
    end_mark = "<!--end-#{name}-->"

    new_value = @match_data[1]

    update_body(mark, end_mark, new_value)
    respond("Done! #{name} is now #{new_value}")
    process_labeling
  end

  def description
    "Set a value for #{name}"
  end

  def example_invocation
    "@#{@bot_name} set #{params[:sample_value] || 'xxxxx'} as #{name}"
  end

end
