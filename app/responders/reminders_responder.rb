require_relative '../lib/responder'
require 'chronic'

class RemindersResponder < Responder

  keyname :reminders

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} remind (.*) in (.*) (.*)\s*$/i
  end

  # Override authorization to allow reviewers/authors to set reminders for themselves
  def authorized?(buffy_context)
    # Check standard authorization first
    role_nil = params[:authorized_roles_in_issue].nil?
    only_nil = params[:only].nil?

    # Standard authorization: check if user belongs to authorized teams or roles
    if !role_nil || !only_nil
      if !role_nil
        authorized_users_in_issue = read_values_from_body([params[:authorized_roles_in_issue]].flatten)
        return true if authorized_users_in_issue.include?("@#{buffy_context.sender}")
      end

      if !only_nil
        return true if user_authorized?(buffy_context.sender)
      end
    elsif role_nil && only_nil
      # No restrictions - public responder
      return true
    end

    # If not authorized by standard rules, check if user is trying to set a reminder for themselves
    # This allows reviewers/authors to set self-reminders even if responder is restricted to editors
    if @match_data
      target = @match_data[1].strip
      sender_login = "@#{user_login(buffy_context.sender).downcase}"
      
      # Allow if target is "me" or the sender themselves
      if target == "me" || user_login(target).downcase == user_login(buffy_context.sender).downcase
        # Check if sender is a reviewer or author  
        # We need to use the existing context's issue_body to check reviewers/authors
        # but check against the buffy_context.sender
        original_sender = @context.sender if @context
        @context.sender = buffy_context.sender if @context
        is_reviewer_or_author = (reviewers_list + authors_list).include?(sender_login)
        @context.sender = original_sender if @context && original_sender
        return is_reviewer_or_author
      end
    end
    
    false
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
    (authors_list + reviewers_list + ["@#{user_login(context.sender).downcase}"]).uniq
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
