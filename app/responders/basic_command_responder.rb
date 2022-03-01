require_relative '../lib/responder'

class BasicCommandResponder < Responder

  keyname :basic_command

  def define_listening
    required_params :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{command}\.?\s*$/i
  end

  def process_message(message)
    respond(params[:message]) if params[:message]
    if params[:messages].is_a?(Array)
      params[:messages].each {|msg| respond(msg)}
    end
    respond_external_template(params[:template_file], locals) if params[:template_file]
    process_external_service(params[:external_call], locals.merge({command: command})) if params[:external_call]
    process_labeling
  end

  def default_description
    "Replies to #{command}"
  end

  def default_example_invocation
    "@#{bot_name} #{command}"
  end
end
