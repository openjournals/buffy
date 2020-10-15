require_relative "../spec_helper.rb"

describe ExternalServiceWorker do

  subject do
    described_class
  end

  let(:response_200) { OpenStruct.new(status: 200, body: "Tests suite OK, build passed") }
  let(:response_200_template) { OpenStruct.new(status: 200, body: '{"result":"passed"}') }
  let(:response_400) { OpenStruct.new(status: 400, body: "error") }

  describe "perform" do
    before do
      @service_params = { 'name' => 'tests', 'command' => 'run specs', 'url' => 'http://tests.openjournals.org' }
      @locals = { 'bot_name' => 'botsci', 'issue_id' => 11, 'repo' => 'openjournals/tests', 'sender' => 'editor1' }
      @worker = described_class.new
      disable_github_calls_for(@worker)
    end

    it "should use POST by default" do
      expected_url = @service_params['url']
      expected_headers = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
      expected_params = @locals.to_json

      expect(Faraday).to_not receive(:get)
      expect(Faraday).to receive(:post).with(expected_url, expected_params, expected_headers).and_return(response_200)
      @worker.perform(@service_params, @locals)
    end

    it "should use GET method if set via settings" do
      expected_url = @service_params['url']
      expected_params = @locals

      expect(Faraday).to_not receive(:post)
      expect(Faraday).to receive(:get).with(expected_url, expected_params).and_return(response_200)
      @worker.perform(@service_params.merge({'method' => 'get'}), @locals)
    end

    it "should respond error message if a 400 or 500 response is received" do
      expect(Faraday).to receive(:post).and_return(response_400)
      expect(@worker).to receive(:respond).with("Error. The tests service is currently unavailable")
      @worker.perform(@service_params, @locals)
    end

    it "should respond body when a 200 response is received" do
      expect(Faraday).to receive(:post).and_return(response_200)
      expect(@worker).to receive(:respond).with("Tests suite OK, build passed")
      @worker.perform(@service_params, @locals)
    end

    it "should respond using a template if present when a 200 response is received" do
      service_params = @service_params.merge({ 'template_file' => 'test_service_reply.md' })
      expect(URI).to receive(:parse).at_least(:once).and_return(URI("buf.fy"))
      expect_any_instance_of(URI::Generic).to receive(:read).once.and_return("Tests {{result}}")

      expect(Faraday).to receive(:post).and_return(response_200_template)
      expect(@worker).to receive(:respond).with("Tests passed")
      @worker.perform(service_params, @locals)
    end

  end

  describe "service query" do
    before do
      @null_response = OpenStruct.new(status: 700, body: "no reply")
      @service = { 'name' => 'tests', 'command' => 'run specs', 'url' => 'URL' }
      @locals = { 'bot_name' => 'botsci', 'issue_id' => 11, 'repo' => 'openjournals/tests', 'sender' => 'editor1' }

      @worker = ExternalServiceWorker.new
      disable_github_calls_for @worker
    end

    it "should include query parameters, mapped parameters and locals" do
      query_params = { 'extra_param' => 'testing', 'api_user_id' => 51 }
      mapping = { 'id' => 'issue_id', 'user' => 'bot_name' }

      mapped_params = { 'id' => 11, 'user' => 'botsci' }
      locals = { 'repo' => 'openjournals/tests', 'sender' => 'editor1' }

      expected_url = @service['url']
      expected_headers = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
      expected_params = query_params.merge(mapped_params, locals).to_json

      expect(Faraday).to receive(:post).with(expected_url, expected_params, expected_headers).and_return(@null_response)

      params = @service.merge({ 'query_params' => query_params, 'mapping' => mapping })
      @worker.perform(params, @locals)
    end
  end
end

