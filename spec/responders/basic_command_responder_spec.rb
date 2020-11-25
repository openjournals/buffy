require_relative "../spec_helper.rb"

describe BasicCommandResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({bot_github_user: "botsci"}, {command: "list editors"}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci list editors")
      expect(@responder.event_regex).to match("@botsci list editors      \n")
      expect(@responder.event_regex).to_not match("@botsci list ")
      expect(@responder.event_regex).to_not match("```@botsci list editors")
    end
  end

  describe "#process_message" do
    before do
      @cmd = "@botsci list editors"
      params = { command: "list editors",
                 message: "Here you have the list of editors",
                 messages: ["msg 1", "msg 2"],
                 template_file: "editor_list.md",
                 data_from_issue: ["x"] }
      @responder = subject.new({ bot_github_user: 'botsci' }, params)
      @responder.context = OpenStruct.new(issue_id: 15,
                                          repo: "tests",
                                          sender: "rev33",
                                          issue_body: "Test Review\n\n ... <!--x-->X<!--end-x-->...")
      disable_github_calls_for(@responder)
    end

    it "should respond configured messages and templates" do
      expect(@responder).to receive(:respond).with("Here you have the list of editors")
      expect(@responder).to receive(:respond).with("msg 1")
      expect(@responder).to receive(:respond).with("msg 2")
      expected_params = { bot_name: "botsci", issue_id: 15, repo: "tests", sender: "rev33", "x"=>"X" }
      expect(@responder).to receive(:render_external_template).
                            with("editor_list.md", expected_params).
                            and_return("editor 1 & editor 2")
      expect(@responder).to receive(:respond).with("editor 1 & editor 2")

      @responder.process_message(@cmd)
    end

    it "should work if no messages present" do
      expect(@responder).to_not receive(:respond)
      @responder.params = { command: "do nothing" }
      @responder.process_message("@botsci do nothing")
    end

    it "should process labeling" do
      expect(@responder).to receive(:process_labeling)
      @responder.params = { command: "only labels" }
      @responder.process_message("@botsci only labels")
    end
  end

  describe "misconfiguration" do
    it "should raise error if command is missing from config" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, {})
      }.to raise_error "Configuration Error in BasicCommandResponder: No value for command."
    end

    it "should raise error if command is empty" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "    " })
      }.to raise_error "Configuration Error in BasicCommandResponder: No value for command."
    end
  end

  describe "documentation" do
    it "#example_invocation shows the custom command" do
      responder = subject.new({ bot_github_user: "botsci" }, { command: "list checkpoints" })
      expect(responder.example_invocation).to eq("@botsci list checkpoints")
    end
  end

end
