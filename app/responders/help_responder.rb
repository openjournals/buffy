require_relative '../lib/responder'

class HelpResponder < Responder

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{@bot_name} #{help_command}\z/i
  end

  def process_message(message)
    descriptions_and_examples = []
    active_responders = ResponderRegistry.new(@settings).responders.select {|r| r.authorized?(context)}
    active_responders.each do |r|
      descriptions_and_examples << [r.description, r.example_invocation]
    end
    respond_template :help, { sender: context.sender, descriptions_and_examples: descriptions_and_examples }
  end

  def help_command
    params[:help_command] || 'help'
  end

  def description
    "List all available commands"
  end

  def example_invocation
    "@#{@bot_name} #{help_command}"
  end
end
