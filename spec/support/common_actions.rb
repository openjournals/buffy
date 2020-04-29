module CommonActions
  def with_secret_token(new_value, &block)
      old_value = subject.settings.gh_secret_token
      subject.settings.gh_secret_token = new_value
      yield
      subject.settings.gh_secret_token = old_value
    end

  def signature_for(payload)
    'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), 'test_secret_token', payload)
  end

  def headers
     { "CONTENT_TYPE" => "application/json" }
  end
end