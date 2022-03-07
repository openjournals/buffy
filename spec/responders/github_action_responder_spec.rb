require_relative "../spec_helper.rb"

describe GithubActionResponder do

  subject do
    described_class
  end

  describe "listening" do
    before do
      settings = { env: {bot_github_user: "botsci"} }
      params = { workflow_repo: "openjournals/joss-reviews", workflow_name: "compiler", command: "generate pdf" }
      @responder = subject.new(settings, params)
    end

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci generate pdf")
      expect(@responder.event_regex).to match("@botsci generate pdf   ")
      expect(@responder.event_regex).to match("@botsci generate pdf   \r\n more")
    end
  end

  describe "#process_message" do
    before do
      settings = { env: {bot_github_user: "botsci"} }
      params = { workflow_repo: "openjournals/joss-reviews", workflow_name: "compiler", command: "generate pdf" }
      @responder = subject.new(settings, params)
      @responder.context = OpenStruct.new(issue_id: 33,
                                          issue_author: "opener",
                                          issue_body: "<!--abc-->XYZ<!--end-abc--><!--p-->33<!--end-p-->",
                                          repo: "openjournals/testing",
                                          sender: "xuanxu")
      disable_github_calls_for(@responder)
    end

    it "should respond custom message if present" do
      @responder.params[:message] = "running tests!"
      expect(@responder).to receive(:respond).with("running tests!")
      @responder.process_message("")
    end

    it "should not respond if there is not custom message" do
      @responder.params[:message] = nil
      expect(@responder).to_not receive(:respond)
      @responder.process_message("")
    end

    it "should process labels" do
      expect(@responder).to receive(:process_labeling)
      @responder.process_message("")
    end

    it "should label issue with defined labels" do
      @responder.params[:add_labels] = ["recommend-accept"]
      expect(@responder).to receive(:label_issue).with(["recommend-accept"])
      @responder.process_message("")
    end

    it "should not label/unlabel the issue if not labels are defined" do
      @responder.params[:add_labels] = nil
      expect(@responder).to receive(:process_labeling)
      expect(@responder).to_not receive(:label_issue)
      expect(@responder).to_not receive(:unlabel_issue)

      @responder.process_message("")
    end

    it "should run workflow" do
      expected_repo = "openjournals/joss-reviews"
      expected_name = "compiler"
      expected_inputs = {}
      expected_ref = "main"
      expect(@responder).to receive(:trigger_workflow).with(expected_repo, expected_name, expected_inputs, expected_ref)
      @responder.process_message("")
    end

    it "should run workflow with custom inputs and params" do
      @responder.params = @responder.params.merge({ workflow_ref: "v1.2.3",
                                                    data_from_issue: ["abc", "p"],
                                                    mapping: { input3: :sender, input4: "p" },
                                                    inputs: { input1: "A", input2: "B" }})

      expected_repo = "openjournals/joss-reviews"
      expected_name = "compiler"
      expected_inputs = { "abc" => "XYZ", input1: "A", input2: "B", input3: "xuanxu", input4: "33"}
      expected_ref = "v1.2.3"
      expect(@responder).to receive(:trigger_workflow).with(expected_repo, expected_name, expected_inputs, expected_ref)
      @responder.process_message("")
    end
  end

  describe "#process_message with run_responder option" do
    before do
      @settings = { env: {bot_github_user: "botsci"} }
      @params = { workflow_repo: "openjournals/joss-reviews", workflow_name: "compiler", command: "generate pdf" }
      @context = OpenStruct.new(issue_id: 33,
                                          issue_author: "opener",
                                          repo: "openjournals/testing",
                                          sender: "xuanxu",
                                          issue_body: "Test Review\n\n<!--extra-data-->ABC123<!--end-extra-data-->")
    end

    it "should call a different responder" do
      other_params = { responder_key: "check_references" }
      responder = subject.new(@settings, @params.merge(run_responder: other_params))
      responder.context = @context
      disable_github_calls_for(responder)

      expect(responder).to receive(:process_other_responder).with(other_params)
      responder.process_message("")
    end

    it "should call several responders" do
      other_params = [{ responder_1: { responder_key: "github_action", responder_name: "compile_pdf", message: "generate pdf" }},
                { responder_2: { responder_key: "hello" }}]
      responder = subject.new(@settings, @params.merge(run_responder: other_params))
      responder.context = @context
      disable_github_calls_for(responder)

      expect(responder).to receive(:process_other_responder).with(other_params[0][:responder_1])
      expect(responder).to receive(:process_other_responder).with(other_params[1][:responder_2])
      responder.process_message("")
    end
  end

  describe "misconfiguration" do
    it "should raise error if workflow_name is missing from config" do
      expect {
        subject.new({env: {bot_github_user: "botsci"}}, { command: "run tests", workflow_repo: "org/repo" })
      }.to raise_error "Configuration Error in GithubActionResponder: No value for workflow_name."
    end

    it "should raise error if there is no command" do
      expect {
        subject.new({env: {bot_github_user: "botsci"}}, { workflow_name: "test", command: " ", workflow_repo: "org/repo" })
      }.to raise_error "Configuration Error in GithubActionResponder: No value for command."
    end

    it "should raise error if there is no workflow_repo" do
      expect {
        subject.new({env: {bot_github_user: "botsci"}}, { workflow_name: "test", command: "run tests" })
      }.to raise_error "Configuration Error in GithubActionResponder: No value for workflow_repo."
    end
  end

  it "#example_invocation can be customized" do
    responder = subject.new({ env: { bot_github_user: "botsci" } },
                            { workflow_name: "compile",
                              workflow_repo: "org/repo",
                              command: "compile file (.*)",
                              example_invocation: "@botsci compile file <FILENAME>" })
    expect(responder.example_invocation).to eq("@botsci compile file <FILENAME>")
  end

end