require_relative "../spec_helper.rb"

describe ThanksResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci thanks for that")
      expect(@responder.event_regex).to match("@botsci thank you!")
      expect(@responder.event_regex).to match("Thanks @botsci!")
      expect(@responder.event_regex).to match("Thanks @botsci! \r\n you're awesome")
      expect(@responder.event_regex).to match("THANK YOU @botsci")
      expect(@responder.event_regex).to_not match("```@botsci thanks")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      disable_github_calls_for(@responder)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("You are welcome")
      @responder.process_message("Thanks @botsci")
    end

    it "should respond with custom reply" do
      @responder.params = { reply: "My pleasure" }
      expect(@responder).to receive(:respond).with("My pleasure")
      @responder.process_message("@botsci thank you!")
    end
  end
end
