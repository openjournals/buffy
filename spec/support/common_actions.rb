module CommonActions
  def with_secret_token(new_value, &block)
      old_value = subject.settings.buffy[:gh_secret_token]
      subject.settings.buffy[:gh_secret_token] = new_value
      yield
      subject.settings.buffy[:gh_secret_token] = old_value
    end

  def signature_for(payload)
    'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), 'test_secret_token', payload)
  end

  def headers
     { "CONTENT_TYPE" => "application/json" }
  end

  def disable_github_calls_for(responder)
    allow(responder).to receive(:issue).and_return(true)
    allow(responder).to receive(:bg_respond).and_return(true)
    allow(responder).to receive(:label_issue).and_return(true)
    allow(responder).to receive(:update_issue).and_return(true)
    allow(responder).to receive(:add_collaborator).and_return(true)
    allow(responder).to receive(:add_assignee).and_return(true)
    allow(responder).to receive(:remove_assignee).and_return(true)
    allow(responder).to receive(:team_id).and_return(nil)

    allow(Octokit::Client).to receive(:new).and_return(true)
  end
end