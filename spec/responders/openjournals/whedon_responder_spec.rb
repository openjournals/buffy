require_relative "../../spec_helper.rb"

describe Openjournals::WhedonResponder do

  subject do
    described_class
  end

  before do
    settings = { env: {bot_github_user: "newbot"} }
    @responder = subject.new(settings, {})
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@whedon approve")
      expect(@responder.event_regex).to match("@whedon commands  \r\n blah blah")
      expect(@responder.event_regex).to_not match("@newbot whatever")
      expect(@responder.event_regex).to_not match("regular comment mentioning @whedon")
    end
  end

  describe "#process_message" do
    before do
      disable_github_calls_for(@responder)
    end

    it "should verify presence of package name" do
      expect(@responder).to receive(:respond).with("My name is now @newbot")
      @responder.process_message("@whedon do something")
    end
  end
end
