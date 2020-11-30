require_relative "../spec_helper.rb"

describe ExternalServiceResponder do

  subject do
    described_class
  end

  describe "listening" do
    before do
      settings = { env: {bot_github_user: "botsci"} }
      params = { name: 'test-service', command: 'run tests', url: 'http://testing.openjournals.org' }
      @responder = subject.new(settings, params)
    end

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci run tests")
      expect(@responder.event_regex).to match("@botsci run tests   \r\n")
    end
  end

  describe "#process_message" do
    before do
      settings = { env: {bot_github_user: "botsci"} }
      params = { name: 'test-service', command: 'run tests', url: 'http://testing.openjournals.org' }
      @responder = subject.new(settings, params)
      @responder.context = OpenStruct.new(issue_id: 33,
                                          repo: "openjournals/testing",
                                          sender: "xuanxu")
      disable_github_calls_for(@responder)
    end

    it "should respond custom message if present" do
      @responder.params[:message] = "running tests!"
      expect(@responder).to receive(:respond).with("running tests!")
      @responder.process_message('')
    end

    it "should not respond if there is not custom message" do
      @responder.params[:message] = nil
      expect(@responder).to_not receive(:respond)
      @responder.process_message('')
    end

    it "should add an ExternalServiceWorker to the jobs queue" do
      expect { @responder.process_message('') }.to change(ExternalServiceWorker.jobs, :size).by(1)
    end

    it "should pass right info to the worker" do
      expected_params = { name: 'test-service', command: 'run tests', url: 'http://testing.openjournals.org' }
      expected_locals = { bot_name: 'botsci', issue_id: 33, repo: 'openjournals/testing', sender: 'xuanxu' }
      expect(ExternalServiceWorker).to receive(:perform_async).with(expected_params, expected_locals)
      @responder.process_message('')
    end
  end

  describe "misconfiguration" do
    it "should raise error if name is missing from config" do
      expect {
        subject.new({env: {bot_github_user: "botsci"}}, { command: 'run tests', url: 'URL' })
      }.to raise_error "Configuration Error in ExternalServiceResponder: No value for name."
    end

    it "should raise error if there is no command" do
      expect {
        subject.new({env: {bot_github_user: "botsci"}}, { name: 'test', command: ' ', url: 'URL' })
      }.to raise_error "Configuration Error in ExternalServiceResponder: No value for command."
    end

    it "should raise error if there is no url" do
      expect {
        subject.new({env: {bot_github_user: "botsci"}}, { name: 'test', command: 'run tests' })
      }.to raise_error "Configuration Error in ExternalServiceResponder: No value for url."
    end
  end

end