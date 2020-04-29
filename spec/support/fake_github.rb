class FakeGitHub < Sinatra::Base
  get '/teams/:id/members' do
    json_response 200, 'team'
  end

  # This is currently not being called.
  post '/repos/ropensci/software-reviews-testing/issues/89/comments' do
    json_response 201, 'issue-comment-created-89'
  end

  private

  # e.g. json_response 200, 'team' for a JSON response fixtures/team.json
  def json_response(response_code, file_name)
    content_type :json
    status response_code
    File.open(File.dirname(__FILE__) + '/fixtures/' + file_name + '.json', 'rb').read
  end
end
