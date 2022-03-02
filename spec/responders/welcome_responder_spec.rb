require_relative "../spec_helper.rb"

describe WelcomeResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new issues" do
      expect(@responder.event_action).to eq("issues.opened")
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
      expect(RepoChecksWorker).to_not receive(:perform_async)
      expect(DOIWorker).to_not receive(:perform_async)
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
      @responder.params = { message: "Hi!" }
      expect(@responder).to receive(:respond).with("Hi!")
      @responder.process_message("")
    end

    it "should respond multiple messages" do
      @responder.params = { messages: ["I'm a friendly bot", "Welcome"] }
      expect(@responder).to receive(:respond).with("I'm a friendly bot")
      expect(@responder).to receive(:respond).with("Welcome")
      @responder.process_message("")
    end
  end

  describe "#process_message with a template" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { template_file: "test.md", data_from_issue: ["reviewer"] })
      @responder.context = OpenStruct.new(issue_id: 5,
                                          issue_author: "opener",
                                          repo: "openjournals/buffy",
                                          sender: "user33",
                                          issue_body: "Test Software Review\n\n<!--reviewer-->@xuanxu<!--end-reviewer-->")
      disable_github_calls_for(@responder)
    end

    it "should populate locals" do
      expected_locals = { issue_id: 5, issue_author: "opener", bot_name: "botsci", repo: "openjournals/buffy", sender: "user33", "reviewer" => "@xuanxu" }

      expect(@responder).to receive(:respond_external_template).with("test.md", expected_locals)
      @responder.process_message("")
    end

    it "should respond to github using the custom template and process labels" do
      expect(URI).to receive(:parse).and_return(URI("buf.fy"))
      expect_any_instance_of(URI::Generic).to receive(:read).once.and_return("Welcome {{sender}}, {{reviewer}} will review your software")

      expected_reply = "Welcome user33, @xuanxu will review your software"
      expect(@responder).to receive(:respond).with(expected_reply)
      expect(@responder).to receive(:process_labeling)
      expect(@responder).to_not receive(:process_reverse_labeling)
      @responder.process_message("")
    end
  end

  describe "#process_message with repo_checks option" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { repo_checks: ""})
      @responder.context = OpenStruct.new(issue_body: "...\n<!--target-repository-->URL<!--end-target-repository-->")
      disable_github_calls_for(@responder)
    end

    it "should not create RepoChecksWorker if no target repository" do
      @responder.context.issue_body = ""
      expect(RepoChecksWorker).to_not receive(:perform_async)
      @responder.process_message("")
    end

    it "should create RepoChecksWorker" do
      expect(RepoChecksWorker).to receive(:perform_async)
      @responder.process_message("")
    end

    it "should pass correct config" do
      expect(RepoChecksWorker).to receive(:perform_async).with(@responder.locals, "URL", "", nil)
      @responder.process_message("")

      @responder.params[:repo_checks] = { checks: ["languages", "license"] }
      expect(RepoChecksWorker).to receive(:perform_async).with(@responder.locals, "URL", "", ["languages", "license"])
      @responder.process_message("")
    end
  end

  describe "#process_message with check_references option" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { check_references: ""})
      @responder.context = OpenStruct.new(issue_body: "...\n<!--target-repository-->URL<!--end-target-repository-->" +
                                                      "...\n<!--branch-->branch-name<!--end-branch-->")
      disable_github_calls_for(@responder)
    end

    it "should not create DOIWorker if no target repository" do
      @responder.context.issue_body = ""
      expect(DOIWorker).to_not receive(:perform_async)
      @responder.process_message("")
    end

    it "should create DOIWorker" do
      expect(DOIWorker).to receive(:perform_async)
      @responder.process_message("")
    end

    it "should pass correct config" do
      @responder.params[:repo_checks] = { checks: ["languages", "license"] }

      expect(DOIWorker).to receive(:perform_async).with(@responder.locals, "URL", "branch-name")
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
                                          repo: "openjournals/testing",
                                          sender: "xuanxu",
                                          issue_body: "Test Review\n\n<!--extra-data-->ABC123<!--end-extra-data-->")
      disable_github_calls_for(@responder)
    end

    it "should add an ExternalServiceWorker to the jobs queue" do
      expect { @responder.process_message("") }.to change(ExternalServiceWorker.jobs, :size).by(1)
    end

    it "should pass right info to the worker" do
      expected_params = { name: "test-service", url: "http://testing.openjournals.org", data_from_issue: ["extra-data"] }
      expected_locals = { "extra-data": "ABC123", bot_name: "botsci", issue_author: "opener", issue_id: 33, repo: "openjournals/testing", sender: "xuanxu" }
      expect(ExternalServiceWorker).to receive(:perform_async).with(expected_params, expected_locals)
      @responder.process_message("")
    end
  end

  describe "#process_message with run_responder option" do
    before do
      @settings = { env: {bot_github_user: "botsci"} }
      @context = OpenStruct.new(issue_id: 33,
                                          issue_author: "opener",
                                          repo: "openjournals/testing",
                                          sender: "xuanxu",
                                          issue_body: "Test Review\n\n<!--extra-data-->ABC123<!--end-extra-data-->")

    end

    it "should call a different responder" do
      params = { responder_key: "github_action", responder_name: "compile_pdf", message: "generate pdf" }
      responder = subject.new(@settings, {run_responder: params})
      responder.context = @context

      expect(responder).to receive(:process_other_responder).with(params)
      responder.process_message("")
    end

    it "should call several responders" do
      params = [{ responder_1: { responder_key: "github_action", responder_name: "compile_pdf", message: "generate pdf" }},
                { responder_2: { responder_key: "hello" }}]
      responder = subject.new(@settings, {run_responder: params})
      responder.context = @context

      expect(responder).to receive(:process_other_responder).with(params[0][:responder_1])
      expect(responder).to receive(:process_other_responder).with(params[1][:responder_2])
      responder.process_message("")
    end
  end

  describe "#process_message closing issue" do
    before do
      @settings = { env: {bot_github_user: "botsci"} }
      @context = OpenStruct.new(issue_body: "...")

      @responder = subject.new({env: {bot_github_user: "botsci"}}, { close: true})
      @responder.context = OpenStruct.new(issue_body: "...")
      disable_github_calls_for(@responder)

    end

    it "should not close issue by default" do
      params = {}
      responder = subject.new(@settings, params)
      responder.context = @context

      expect(responder).to_not receive(:close_issue)
      responder.process_message("")
    end

    it "should close issue if close: true" do
      params = { close: true }
      responder = subject.new(@settings, params)
      responder.context = @context

      expect(responder).to receive(:close_issue)
      responder.process_message("")
    end
  end

  describe "misconfiguration" do
    it "should raise error if there is no name for the service" do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {external_service: { url: "URL" }})

      expect {
        @responder.process_message("")
      }.to raise_error "Configuration Error in WelcomeResponder: No value for name."
    end

    it "should raise error if there is no url for the service" do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {external_service: { name: "test" }})

      expect {
        @responder.process_message("")
      }.to raise_error "Configuration Error in WelcomeResponder: No value for url."
    end
  end
end
