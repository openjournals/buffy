require_relative "../spec_helper.rb"

describe WelcomeResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({bot_github_user: "botsci"}, {}) }

    it "should listen to new issues" do
      expect(@responder.event_action).to eq("issues.opened")
    end

    it "should not define regex" do
      expect(@responder.event_regex).to be_nil
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({ bot_github_user: 'botsci' }, {})
      disable_github_calls_for(@responder)
    end

    it "should respond custom reply" do
      @responder.params = { reply: "Hi!" }
      expect(@responder).to receive(:respond).with("Hi!")
      @responder.process_message("")
    end

    it "should respond to github" do
      reply = "Hi!, I'm @botsci, a friendly bot.\n\nType ```@botsci help``` to discover how I can help you."
      expect(@responder).to receive(:respond).with(reply)
      @responder.process_message("")
    end
  end
end
