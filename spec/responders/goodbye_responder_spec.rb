require_relative "../spec_helper.rb"

describe GoodbyeResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new issues" do
      expect(@responder.event_action).to eq("issues.closed")
    end

    it "should not define regex" do
      expect(@responder.event_regex).to be_nil
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      @responder.context = OpenStruct.new(issue_body: "...\n<!--target-repository-->URL<!--end-target-repository-->")
      disable_github_calls_for(@responder)
    end

    it "should process labels" do
      expect(@responder).to receive(:process_labeling)
      expect(@responder).to_not receive(:process_reverse_labeling)
      @responder.process_message("")
    end

    it "should by default do nothing" do
      expect(@responder).to_not receive(:respond)
      expect(@responder).to_not receive(:respond_external_template)
      expect(ExternalServiceWorker).to_not receive(:perform_async)
      @responder.process_message("")
    end
  end

  describe "#process_message with messages" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      disable_github_calls_for(@responder)
    end

    it "should respond a message" do
      @responder.params = { message: "Bye!" }
      expect(@responder).to receive(:respond).with("Bye!")
      @responder.process_message("")
    end

    it "should respond multiple messages" do
      @responder.params = { messages: ["Closing the issue", "Bye"] }
      expect(@responder).to receive(:respond).with("Closing the issue")
      expect(@responder).to receive(:respond).with("Bye")
      @responder.process_message("")
    end
  end

  describe "#process_message with a template" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { template_file: "thanks.md", data_from_issue: ["reviewer"] })
      @responder.context = OpenStruct.new(issue_id: 5,
                                          issue_author: "opener",
                                          issue_title: "Test paper",
                                          repo: "openjournals/buffy",
                                          sender: "user33",
                                          issue_body: "Test Software Review\n\n<!--reviewer-->@xuanxu<!--end-reviewer-->")
      disable_github_calls_for(@responder)
    end

    it "should populate locals" do
      expected_locals = { issue_id: 5, issue_author: "opener", issue_title: "Test paper", bot_name: "botsci", repo: "openjournals/buffy", sender: "user33", "reviewer" => "@xuanxu" }

      expect(@responder).to receive(:respond_external_template).with("thanks.md", expected_locals)
      @responder.process_message("")
    end

    it "should respond to github using the custom template and process labels" do
      expect(URI).to receive(:parse).and_return(URI("buf.fy"))
      expect_any_instance_of(URI::Generic).to receive(:read).once.and_return("Thanks for the help {{reviewer}}!")

      expected_reply = "Thanks for the help @xuanxu!"
      expect(@responder).to receive(:respond).with(expected_reply)
      expect(@responder).to receive(:process_labeling)
      expect(@responder).to_not receive(:process_reverse_labeling)
      @responder.process_message("")
    end
  end

  describe "#process_message with external service" do
    before do
      settings = { env: {bot_github_user: "botsci"} }
      params = { name: "test-service", url: "http://testing.openjournals.org", data_from_issue: ["extra-data"] }
      @responder = subject.new(settings, {external_service: params})
      @responder.context = OpenStruct.new(issue_id: 33,
                                          issue_author: "opener",
                                          issue_title: "Test paper",
                                          repo: "openjournals/testing",
                                          sender: "xuanxu",
                                          issue_body: "Test Review\n\n<!--extra-data-->ABC123<!--end-extra-data-->")
      disable_github_calls_for(@responder)
    end

    it "should add an ExternalServiceWorker to the jobs queue" do
      expect { @responder.process_message("") }.to change(ExternalServiceWorker.jobs, :size).by(1)
    end

    it "should pass right info to the worker" do
      expected_params = { "name" => "test-service", "url" => "http://testing.openjournals.org", "data_from_issue" => ["extra-data"] }
      expected_locals = { "extra-data" => "ABC123", "bot_name" => "botsci", "issue_author" => "opener", "issue_title" => "Test paper", "issue_id" => 33, "repo" => "openjournals/testing", "sender" => "xuanxu" }
      expect(ExternalServiceWorker).to receive(:perform_async).with(expected_params, expected_locals)
      @responder.process_message("")
    end
  end

  describe "misconfiguration" do
    it "should raise error if there is no name for the service" do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {external_service: { url: "URL" }})

      expect {
        @responder.process_message("")
      }.to raise_error "Configuration Error in GoodbyeResponder: No value for name."
    end

    it "should raise error if there is no url for the service" do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {external_service: { name: "test" }})

      expect {
        @responder.process_message("")
      }.to raise_error "Configuration Error in GoodbyeResponder: No value for url."
    end
  end
end
