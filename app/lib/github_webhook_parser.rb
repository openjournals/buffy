require 'ostruct'
require 'json'
require 'openssl'

module GitHubWebhookParser

  def parse_webhook
    begin
      request.body.rewind
      @payload = JSON.parse(request.body.read)
      @event = request.get_header 'HTTP_X_GITHUB_EVENT'
    rescue JSON::ParserError
      halt 400, 'Malformed request'
    end

    halt 422, 'No payload' if @payload.nil?
    halt 422, 'No event' if @event.nil?

    @action = @payload['action']

    if @event == 'issues'
      @message = @payload.dig('issue', 'body')
    elsif @event == 'issue_comment'
      @message = @payload.dig('comment', 'body')
    else
      halt 200, "Event discarded"
    end

    @sender = @payload.dig('sender', 'login')
    @issue_id = @payload.dig('issue', 'number')
    @repo = @payload.dig('repository', 'full_name')

    @gh_context = OpenStruct.new(
      action: @action,
      event: @event,
      issue_id: @issue_id,
      message: @message,
      repo: @repo,
      sender: @sender,
      event_action: "#{@event}.#{@action}",
      #payload: @payload
    )
  end

  def verify_signature
    secret_token = settings.buffy[:gh_secret_token]
    gh_signature = request.get_header 'HTTP_X_HUB_SIGNATURE'
    return halt 500, "Can't compute signature" if secret_token.nil? || secret_token.empty?
    return halt 403, 'Request missing signature' if gh_signature.nil? || gh_signature.empty?
    request.body.rewind
    payload_body = request.body.read
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret_token, payload_body)
    return halt 403, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, gh_signature)
  end
end
