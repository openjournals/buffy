require "ostruct"
require "json"
require "openssl"
require "rack"

module Issue
  class Webhook
    attr_accessor :secret_token
    attr_accessor :request
    attr_accessor :accept_origin
    attr_accessor :discard_sender
    attr_accessor :accept_events
    attr_accessor :error
    attr_accessor :payload

    # Initialize the Issue::Webhook object
    # This method should receive a Hash with the following settings:
    #   secret_token: the GitHub secret token needed to verify the request signature.
    #   accept_events: an Array of valid values for the HTTP_X_GITHUB_EVENT header. If empty any event will be processed.
    #   origin: the respository where the webhook should be sent to be accepted. If empty any request will be processed.
    #   discard_sender: an optional GitHub user handle to discard all events triggered by it.
    def initialize(settings={})
      @secret_token = settings[:secret_token]
      @accept_origin = settings[:origin]
      @accept_events = [settings[:accept_events]].flatten.compact.uniq.map(&:to_s)
      @discard_sender = parse_discard_senders(settings[:discard_sender])
    end

    # This method will parse the passed request.
    # If the request signature is incorrect or any of the conditions set
    # via the initialization settings are not met an error will be created
    # with the appropiate html status and message. Otherwise a Issue::Payload
    # object will be created with the information contained in the request payload.
    #
    # This method returns a pair [payload, error] where only one of them will be nil
    def parse_request(request)
      @payload = nil
      @error = nil
      @request = request

      if verify_signature
        parse_payload
      end

      return [payload, error]
    end

    # This method returns True if parsing a request has generated an Issue::Error object
    # That object will be available at the #error accessor method.
    def errored?
      !error.nil?
    end

    private

    def parse_discard_senders(discard_sender_settings)
      if discard_sender_settings.is_a?(String)
        return { discard_sender_settings => [] }
      elsif discard_sender_settings.is_a?(Hash)
        return discard_sender_settings.transform_keys {|k| k.to_s }.transform_values {|v| [v].flatten}
      else
        return {}
      end
    end

    def verify_signature
      gh_signature = request.get_header "HTTP_X_HUB_SIGNATURE"
      return error!(500, "Can't compute signature") if secret_token.nil? || secret_token.empty?
      return error!(403, "Request missing signature") if gh_signature.nil? || gh_signature.empty?
      request.body.rewind
      payload_body = request.body.read
      signature = "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), secret_token, payload_body)
      return error!(403, "Signatures didn't match!") unless Rack::Utils.secure_compare(signature, gh_signature)
      true
    end

    def parse_payload
      begin
        request.body.rewind
        json_payload = JSON.parse(request.body.read)
        event = request.get_header "HTTP_X_GITHUB_EVENT"
        sender = json_payload.dig("sender", "login")
        origin = json_payload.dig("repository", "full_name")
      rescue JSON::ParserError
        return error!(400, "Malformed request")
      end

      return error!(422, "No payload") if json_payload.nil? || json_payload.empty?
      return error!(422, "No event") if event.nil?
      return error!(200, "Event discarded") unless (accept_events.empty? || accept_events.include?(event))
      return error!(200, "Event origin discarded") if (discard_sender[sender] == [] || discard_sender[sender].to_a.include?(event))
      return error!(403, "Event origin not allowed") if (accept_origin && origin != accept_origin)

      @payload = Issue::Payload.new(json_payload, event)
    end

    def error!(status, msg)
      @error = Issue::Error.new(status, msg)
      false
    end
  end
end