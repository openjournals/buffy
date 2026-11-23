require_relative "../lib/responder"

class SetValueResponder < Responder

  keyname :set_value

  def define_listening
    required_params :name

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} set (.*) as #{alias_or_name}\.?\s*$/i
  end

  def process_message(message)
    mark = "<!--#{name}-->"
    end_mark = "<!--end-#{name}-->"

    new_value = @match_data[1]
    reply = "Done! #{alias_or_name} is now #{new_value}"

    errored = false

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

    if params[:template_file] && !errored
      respond_external_template(params[:template_file], locals.merge(name: name, value: new_value))
    else
      respond(reply)
    end

    unless errored
      process_labeling
      process_external_service(params[:external_call], locals.merge({new_value: new_value})) if params[:external_call]
      run_other_responders(new_value) if params[:run_responder]
    end
  end

  # Runs the responders configured in run_responder, one or a list of them like in the welcome
  # responder. {{value}} in a responder's message is replaced with the value just set.
  def run_other_responders(new_value)
    configs = params[:run_responder].is_a?(Array) ? params[:run_responder].flat_map(&:values) : [params[:run_responder]]

    configs.each do |other_responder|
      other_responder = other_responder.dup
      if other_responder[:message]
        other_responder[:message] = apply_hash_to_template(other_responder[:message].dup, locals.merge(value: new_value))
      end
      process_other_responder(other_responder)
    end
  end

  def alias_or_name
    params[:aliased_as] || name
  end

  def default_description
    "Set a value for #{alias_or_name}"
  end

  def default_example_invocation
    "@#{bot_name} set #{params[:sample_value] || 'xxxxx'} as #{alias_or_name}"
  end

end
