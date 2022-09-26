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

    unless targets.include?(human)
      respond("#{human} doesn't seem to be a reviewer or author for this submission.")
      return false
    end

    schedule_at = target_time(size, unit)

    if schedule_at
      ReviewReminderWorker.perform_at(schedule_at, serializable(locals), human, authors_list.include?(human))
      respond("Reminder set for #{human} in #{size} #{unit}")
    else
      respond ("I don't recognize this description of time: '#{size}' '#{unit}'.")
    end
  end

  def targets
    (authors_list + reviewers_list).uniq
  end

  def reviewers_list
    @reviewers_list ||= reviewers_value.inject([]) {|re, value| re + read_value_from_body(value).split(",").map(&:strip)}
    @reviewers_list.compact.uniq
  end

  def authors_list
    @authors_list ||= authors_value.inject([]) {|au, value| au + read_value_from_body(value).split(",").map(&:strip)}
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

  def target_time(size, unit)
    Chronic.parse("in #{size} #{unit}")
  end

  def default_description
    "Remind an author or reviewer to return to a review after a " + "\n" +
    "# certain period of time (supported units days and weeks)"
  end

  def default_example_invocation
    "@#{bot_name} remind @reviewer in 2 weeks"
  end
end
