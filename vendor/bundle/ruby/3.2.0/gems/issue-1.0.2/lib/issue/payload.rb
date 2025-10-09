require "ostruct"
require "json"

module Issue
  class Payload
    attr_accessor :context

    # Initialize Issue::Payload object with:
    #
    #   json_data: the parsed json sent from a GitHub webhook
    #   event: the value of the HTTP_X_GITHUB_EVENT header
    #
    # Initializing a new Issue::Payload instance makes all this info
    # from the json webhook available via accessor methods:
    #
    #   action
    #   event
    #   issue_id
    #   issue_title
    #   issue_body
    #   issue_author
    #   repo
    #   sender
    #   event_action
    #   raw_payload
    #
    # And when the event is 'issue_comment' also:
    #
    #   comment_body
    #   comment_created_at
    #   comment_url
    #
    def initialize(json_data, event)
      action = json_data.dig("action")
      sender = json_data.dig("sender", "login")
      repo = json_data.dig("repository", "full_name")

      if event == "pull_request"
        issue_id = json_data.dig("pull_request", "number")
        issue_title = json_data.dig("pull_request", "title")
        issue_body = json_data.dig("pull_request", "body")
        issue_labels = json_data.dig("pull_request", "labels")
        issue_author = json_data.dig("pull_request", "user", "login")
      else
        issue_id = json_data.dig("issue", "number")
        issue_title = json_data.dig("issue", "title")
        issue_body = json_data.dig("issue", "body")
        issue_labels = json_data.dig("issue", "labels")
        issue_author = json_data.dig("issue", "user", "login")
      end

      @context = OpenStruct.new(
        action: action,
        event: event,
        issue_id: issue_id,
        issue_title: issue_title,
        issue_body: issue_body,
        issue_author: issue_author,
        issue_labels: issue_labels,
        repo: repo,
        sender: sender,
        event_action: "#{event}.#{action}",
        raw_payload: json_data
      )

      if event == "issue_comment"
        @context[:comment_id] = json_data.dig("comment", "id")
        @context[:comment_body] = json_data.dig("comment", "body")
        @context[:comment_created_at] = json_data.dig("comment", "created_at")
        @context[:comment_url] = json_data.dig("comment", "html_url")
      end

      @context.each_pair do |method_name, value|
        define_singleton_method(method_name) {value}
      end
    end

    # True if the payload is coming from an issue that has just been opened
    def opened?
      action == "opened" || action == "reopened"
    end

    # True if the payload is coming from an issue that has just been closed
    def closed?
      action == "closed"
    end

    # True if the payload is coming from a new comment
    def commented?
      action == "created"
    end

    # True if the payload is coming from an edition of a comment or issue
    def edited?
      action == "edited"
    end

    # True if the payload is coming from locking an issue
    def locked?
      action == "locked"
    end

    # True if the payload is coming from unlocking an issue
    def unlocked?
      action == "unlocked"
    end

    # True if the payload is coming from pinning or unpinning an issue
    def pinned?
      action == "pinned" || action == "unpinned"
    end

    # True if the payload is coming from un/assigning an issue
    def assigned?
      action == "assigned" || action == "unassigned"
    end

    # True if the payload is coming from un/labeling an issue
    def labeled?
      action == "labeled" || action == "unlabeled"
    end
  end
end