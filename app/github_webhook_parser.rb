require 'ostruct'
require 'json'
require 'openssl'

module GitHubWebhookParser

  def parse_webhook
    begin
      @payload = JSON.parse(params[:payload])
      @event = request.env["X-GitHub-Event"]
    rescue JSON::ParserError
      halt 400, "Malformed request"
    end

    halt 422 if payload.nil?
    halt 422 if @event.nil?

    @action = @payload['action']

    if @action == 'opened' || @action == 'closed'
      @message = payload['issue']['body']
    elsif @action == 'created'
      @message = payload['comment']['body']
    end

    @sender = payload['sender']['login']
    @issue_id = payload['issue']['number']
    @repo = payload['repository']['full_name']

    @context = OpenStruct.new(
      :action => @action,
      :event => @event,
      :issue_id => @issue_id,
      :message => @message,
      :repo => @repo,
      :payload => @payload,
      :sender => @sender,
      :event_action => "#{@event}.#{@action}"
    )
  end

  def verify_signature
    secret_token = settings.gh_secret_token
    gh_signature = request.env['HTTP_X_HUB_SIGNATURE']
    return halt 500, "Can't compute signature" if secret_token.nil? || secret_token.empty?
    return halt 403, "Request missing signature" if gh_signature.nil? || gh_signature.empty?
    request.body.rewind
    payload_body = request.body.read
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret_token, payload_body)
    return halt 403, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, gh_signature)
  end
end
