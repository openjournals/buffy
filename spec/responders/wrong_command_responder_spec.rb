require_relative "../spec_helper.rb"

describe WrongCommandResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {command: "list editors"}) }

    it "should listen to wrong_command events" do
      expect(@responder.event_action).to eq("wrong_command")
    end

    it "should define a catch-all regex" do
      expect(@responder.event_regex).to match("@botsci whatever")
      expect(@responder.event_regex).to match("@botsci reviawwers   \n")
      expect(@responder.event_regex).to_not match(" @botsci whatever")
      expect(@responder.event_regex).to_not match("```@botsci whatever")
    end
  end

  describe "#process_message" do
    before do
      @cmd = "@botsci blah blah"
      @responder = subject.new({env: { bot_github_user: "botsci" }, responders: { help: {} }}, {})
      @responder.context = OpenStruct.new(issue_id: 15,
                                          issue_author: "opener",
                                          repo: "tests",
                                          sender: "rev33",
                                          issue_body: "Test Review\n\n ... <!--x-->X<!--end-x-->...")
      expect(@responder.responds_to?(@cmd)).to be_truthy
      disable_github_calls_for(@responder)
    end

    it "should respond default reply" do
      default_reply = "I'm sorry human, I don't understand that. You can see what commands I support by typing:\n\n`@botsci help`\n"
      expect(@responder).to receive(:respond).with(default_reply)

      @responder.process_message(@cmd)
    end

    it "should respond with custom message" do
      @responder.params = { message: "Say what?"}
      expect(@responder).to receive(:respond).with("Say what?")

      @responder.process_message(@cmd)
    end

    it "should respond with custom template" do
      @responder.params = { template_file: "wrong_command.md" }
      expected_params = { bot_name: "botsci", issue_author: "opener", issue_id: 15, repo: "tests", sender: "rev33", match_data_1: "blah blah" }
      expect(@responder).to receive(:render_external_template).
                            with("wrong_command.md", expected_params).
                            and_return("I don't understand `blah blah`")
      expect(@responder).to receive(:respond).with("I don't understand `blah blah`")

      @responder.process_message(@cmd)
    end

    it "should give precedence to template over custom message" do
      @responder.params = { template_file: "wrong_command.md", message: "what?"}
      expected_params = { bot_name: "botsci", issue_author: "opener", issue_id: 15, repo: "tests", sender: "rev33", match_data_1: "blah blah" }
      expect(@responder).to receive(:render_external_template).
                            with("wrong_command.md", expected_params).
                            and_return("I don't understand `blah blah`")
      expect(@responder).to receive(:respond).with("I don't understand `blah blah`")
      expect(@responder).to_not receive(:respond).with("what?")

      @responder.process_message(@cmd)
    end

    it "should do nothing if ignore is true" do
      @responder.params = { ignore: true, template_file: "wrong_command.md", message: "what?"}

      expect(@responder).to_not receive(:render_external_template)
      expect(@responder).to_not receive(:respond)

      @responder.process_message(@cmd)
    end
  end

  it "should be hidden" do
    responder = subject.new({env: {bot_github_user: "botsci"}}, {})
    expect(responder).to be_hidden
  end
end
