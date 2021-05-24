require_relative "../spec_helper.rb"

describe HelloResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("Hello @botsci")
      expect(@responder.event_regex).to match("Hello @botsci!")
      expect(@responder.event_regex).to match("Hello @botsci.")
      expect(@responder.event_regex).to match("hi @botsci")
      expect(@responder.event_regex).to_not match("```Hello @botsci")
      expect(@responder.event_regex).to_not match("Hey @botsci!")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      disable_github_calls_for(@responder)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("Hi!")
      @responder.process_message("Hello @botsci")
    end
  end
end
