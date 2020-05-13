require_relative "../spec_helper.rb"

describe HelpResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({bot_github_user: "botsci"}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci help")
      expect(@responder.event_regex).to_not match("```@botsci help")
    end

    it "should allow invocation with custom command" do
      custom_responder = subject.new({bot_github_user: "botsci"}, {help_command: "commands"})
      expect(custom_responder.event_regex).to match("@botsci commands")
      expect(custom_responder.event_regex).to_not match("@botsci help")
      expect(custom_responder.example_invocation).to eq("@botsci commands")
    end
  end

  describe "#process_message" do
    before do
      @settings = { bot_github_user: "botsci",
                   teams: { editors: 2009411 },
                   responders: { "hello" => nil,
                                 "help" => nil,
                                 "assign_reviewer_n" => { only: "editors" } } }
      @responder = subject.new(@settings, {})
      @responder.context = OpenStruct.new(sender: "sender")
      disable_github_calls_for(@responder)
    end

    it "should respond the help erb template to github" do
      allow_any_instance_of(Responder).to receive(:authorized?).and_return(true)

      responders = [HelloResponder.new(@settings,{}), HelpResponder.new(@settings,{}), AssignReviewerNResponder.new(@settings,{})]
      expected_descriptions = responders.map {|r| [r.description, r.example_invocation]}
      expected_locals = { sender: "sender", descriptions_and_examples: expected_descriptions}

      expect(@responder).to receive(:respond_template).once.with(:help, expected_locals)
      @responder.process_message("@botsci help")
    end

    it "should list only allowed responders" do
      allow_any_instance_of(AssignReviewerNResponder).to receive(:authorized?).and_return(false)

      responders = [HelloResponder.new(@settings,{}), HelpResponder.new(@settings,{})]
      expected_descriptions = responders.map {|r| [r.description, r.example_invocation]}
      expected_locals = { sender: "sender", descriptions_and_examples: expected_descriptions}

      expect(@responder).to receive(:respond_template).once.with(:help, expected_locals)
      @responder.process_message("@botsci help")
    end
  end
end
