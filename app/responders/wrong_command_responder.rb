require_relative '../lib/responder'

class WrongCommandResponder < Responder

  keyname :wrong_command

  def define_listening
    @event_action = "wrong_command"
    @event_regex = /\A@#{bot_name} (.*)/i
  end

  def process_message(message)
    if params[:ignore] == true
      return
    elsif params[:template_file]
      respond_external_template(params[:template_file], locals)
    elsif params[:message]
      respond(params[:message])
    else
      help_command_settings = @settings[:responders][:help]
      help_command_settings = help_command_settings[0].values[0] if help_command_settings.is_a?(Array)
      help_command = HelpResponder.new(@settings, help_command_settings).example_invocation
      respond "I'm sorry human, I don't understand that. You can see what commands I support by typing:\n\n`#{help_command}`\n"
    end
  end

  def default_description
    "Replies when the received command is not understood"
  end

  def default_example_invocation
    "@#{bot_name}: this is a message you don't understand"
  end

  def hidden?
    true
  end
end
