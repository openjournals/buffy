require_relative "../spec_helper.rb"

describe HelpResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: { bot_github_user: "botsci" }}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci help")
      expect(@responder.event_regex).to match("@botsci help!")
      expect(@responder.event_regex).to match("@botsci help.")
      expect(@responder.event_regex).to_not match("```@botsci help")
    end

    it "should allow invocation with custom command" do
      custom_responder = subject.new({env: {bot_github_user: "botsci"}}, {help_command: "commands"})
      expect(custom_responder.event_regex).to match("@botsci commands")
      expect(custom_responder.event_regex).to_not match("@botsci help")
      expect(custom_responder.example_invocation).to eq("@botsci commands")
    end
  end

  describe "#process_message" do
    before do
      @settings = { env: { bot_github_user: "botsci" },
                    teams: { editors: 2009411 },
                    responders: { "hello" => nil,
                                  "help" => nil,
                                  "assign_editor" => { only: "editors" }}}
      @responder = subject.new(@settings, {})

      @hello = HelloResponder.new(@settings,{})
      @help = HelpResponder.new(@settings,{})
      @assign_editor = AssignEditorResponder.new(@settings,{})

      @context = OpenStruct.new(sender: "sender", event: "issue_comments", event_action: "issue_comment.created")
      @responder.context = @context

      disable_github_calls_for(@responder)
    end

    it "should respond the help erb template to github" do
      allow_any_instance_of(Responder).to receive(:authorized?).and_return(true)

      responders = [@hello, @help, @assign_editor]
      expected_descriptions = responders.map {|r| [r.description, r.example_invocation]}
      expected_locals = { sender: "sender", descriptions_and_examples: expected_descriptions}

      expect(@responder).to receive(:respond_template).once.with(:help, expected_locals)
      @responder.process_message("@botsci help")
    end

    it "should manage responder with multiple invocations" do
      settings = { env: { bot_github_user: "botsci" }, responders: { "help" => nil, "add_remove_assignee" => nil }}
      multiple_invocations = AddAndRemoveAssigneeResponder.new(settings, {})
      expected = [[@help.description, @help.example_invocation],
                  [multiple_invocations.description[0], multiple_invocations.example_invocation[0]],
                  [multiple_invocations.description[1], multiple_invocations.example_invocation[1]]]
      expected_locals = { sender: "sender", descriptions_and_examples: expected}

      responder = subject.new(settings, {})
      responder.context = @context

      expect(responder).to receive(:respond_template).once.with(:help, expected_locals)
      responder.process_message("@botsci help")
    end

    it "should list only allowed responders" do
      allow_any_instance_of(AssignEditorResponder).to receive(:authorized?).and_return(false)

      responders = [@hello, @help]
      expected_descriptions = responders.map {|r| [r.description, r.example_invocation]}
      expected_locals = { sender: "sender", descriptions_and_examples: expected_descriptions}

      expect(@responder).to receive(:respond_template).once.with(:help, expected_locals)
      @responder.process_message("@botsci help")
    end

    it "should not list hidden responders" do
      allow_any_instance_of(Responder).to receive(:authorized?).and_return(true)
      new_settings = @settings.merge({ responders: @settings[:responders].merge({"hello" => { hidden: true }}) })
      responder = subject.new(new_settings, {})
      responder.context = @context
      disable_github_calls_for(responder)

      responders = [@help, @assign_editor]
      expected_descriptions = responders.map {|r| [r.description, r.example_invocation]}
      expected_locals = { sender: "sender", descriptions_and_examples: expected_descriptions}

      expect(responder).to receive(:respond_template).once.with(:help, expected_locals)
      responder.process_message("@botsci help")
    end

    it "should not list responders not listening to comments" do
      allow_any_instance_of(Responder).to receive(:authorized?).and_return(true)
      allow_any_instance_of(Responder).to receive(:hidden?).and_return(false)
      no_comment_responder = Responder.new(@settings, {})
      no_comment_responder.event_action = "issues"

      responders = [@help, no_comment_responder, @assign_editor]

      expect_any_instance_of(ResponderRegistry).to receive(:load_responders!).and_return(true)
      expect_any_instance_of(ResponderRegistry).to receive(:responders).and_return(responders)

      expected_responders = responders - [no_comment_responder]
      expected_descriptions = expected_responders.map {|r| [r.description, r.example_invocation]}
      expected_locals = { sender: "sender", descriptions_and_examples: expected_descriptions}

      expect(@responder).to receive(:respond_template).once.with(:help, expected_locals)
      @responder.process_message("@botsci help")
    end
  end
end
