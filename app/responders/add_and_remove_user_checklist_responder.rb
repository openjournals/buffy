require_relative '../lib/responder'

class AddAndRemoveUserChecklistResponder < Responder

  keyname :add_remove_checklist

  def define_listening
    required_params :template_file

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} (add|remove) checklist for ([@\w-]+)\.?\s*\z/i
  end

  def process_message(message)
    add_or_remove = @match_data[1].downcase
    user = @match_data[2]

    @mark = "<!--checklist-for-#{user}-->"
    @end_mark = "<!--end-checklist-for-#{user}-->"

    @previous = read_from_body(@mark, @end_mark)

    if add_or_remove == "add"
      add_checklist user
    elsif add_or_remove == "remove"
      remove_checklist user
    end
  end

  def add_checklist(user)
    if @previous.empty?
      checklist = "\n" + @mark +
                  "\n" + "## Review checklist for " + user +
                  "\n" + render_external_template(template_file, locals) +
                  "\n" + @end_mark+ "\n"

      append_to_body checklist
      respond("Checklist added for #{user}")
      process_labeling
    else
      respond("There is already a checklist for #{user}")
    end
  end

  def remove_checklist(user)
    if @previous.empty?
      respond("There is not a checklist for #{user}")
    else
      delete_from_body(@mark, @end_mark, true)
      respond("Checklist for #{user} removed")
      process_reverse_labeling
    end
  end

  def default_description
    ["Add review checklist for a user",
     "Remove the checklist for a user"]
  end

  def default_example_invocation
    ["@#{bot_name} add checklist for @username",
     "@#{bot_name} remove checklist for @username"]
  end
end
