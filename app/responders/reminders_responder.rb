require_relative '../lib/responder'
require 'chronic'

class RemindersResponder < Responder

  keyname :reminders

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} remind (.*) in (.*) (.*)\s*$/i
  end

  def process_message(message)
    human = @match_data[1].strip
    size = @match_data[2].strip
    unit = @match_data[3].strip

    human = "@#{user_login(context.sender)}" if human == "me"

    unless targets.include?(human.downcase)
      respond("#{human} doesn't seem to be a reviewer or author for this submission.")
      return false
    end

    schedule_at = target_time(size, unit)

    if schedule_at
      if user_login(human).downcase == user_login(context.sender).downcase
        human = "@#{user_login(context.sender)}"
        msg = ":wave: #{human}, please take a look at the state of the submission (this is an automated reminder)."
        AsyncMessageWorker.perform_at(schedule_at, serializable(locals), msg)
      else
        ReviewReminderWorker.perform_at(schedule_at, serializable(locals), human, authors_list.include?(human.downcase))
      end
      respond("Reminder set for #{human} in #{size} #{unit}")
    else
      respond ("I don't recognize this description of time: '#{size}' '#{unit}'.")
    end
  end

  def targets
    (authors_list + reviewers_list + [sender_user]).uniq
  end

  def reviewers_list
    @reviewers_list ||= reviewers_value.inject([]) {|re, value| re + read_value_from_body(value).split(",").map(&:strip).map(&:downcase)}
    @reviewers_list.compact.uniq
  end

  def authors_list
    @authors_list ||= authors_value.inject([]) {|au, value| au + read_value_from_body(value).split(",").map(&:strip).map(&:downcase)}
    @authors_list.compact.uniq
  end

  def reviewers_value
    @reviewers_value = params[:reviewers] || "reviewers-list"
    @reviewers_value = [@reviewers_value].flatten
  end

  def authors_value
    @authors_value = params[:authors] || "author-handle"
    @authors_value = [@authors_value].flatten
  end

  def sender_user
    "@#{user_login(context.sender).downcase}"
  end

  def target_time(size, unit)
    Chronic.parse("in #{size} #{unit}")
  end

  def default_description
    "Remind an author, a reviewer or the editor to return to a review after a " + "\n" +
    "# certain period of time (supported units days and weeks)"
  end

  def default_example_invocation
    "@#{bot_name} remind @reviewer in 2 weeks"
  end
end
