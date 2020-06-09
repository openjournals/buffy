require_relative "../spec_helper.rb"

describe LabelCommandResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({ bot_github_user: "botsci" }, { command: "recommend publication" }) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci recommend publication")
      expect(@responder.event_regex).to match("@botsci recommend publication   \r\n")
      expect(@responder.event_regex).to_not match("@botsci recommend publication now")
      expect(@responder.event_regex).to_not match("@botsci recommend")
      expect(@responder.event_regex).to_not match("@botsci recommend public")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({ bot_github_user: "botsci" },
                               { name: "review_ok",
                                 command: "recommend publication",
                                 labels: ["reviewed", "approved", "pending publication"] })
      disable_github_calls_for(@responder)
      @msg = "@botsci recommend publication"
    end

    it "should label isuue with defined labels" do
      expect(@responder).to receive(:label_issue).with(["reviewed", "approved", "pending publication"])
      @responder.process_message(@msg)
    end
  end

  describe "misconfiguration" do
    it "should raise error if command is missing from config" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, {})
      }.to raise_error "Configuration Error in LabelCommandResponder: No value for command."
    end

    it "should raise error if command is empty" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "    " })
      }.to raise_error "Configuration Error in LabelCommandResponder: No value for command."
    end

    it "should raise error if labels param is missing from config" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "reviewed" })
        @responder.process_message(@msg)
      }.to raise_error "Configuration Error in LabelCommandResponder: No labels specified."
    end

    it "should raise error if labels param is empty" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "reviewed", labels: [] })
        @responder.process_message(@msg)
      }.to raise_error "Configuration Error in LabelCommandResponder: No labels specified."
    end

    it "should raise error if labels param is not an array" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "reviewed", labels: "reviewed" })
        @responder.process_message(@msg)
      }.to raise_error "Configuration Error in LabelCommandResponder: No labels specified."
    end
  end

  describe "documentation" do
    before do
      @responder = subject.new({ bot_github_user: "botsci" }, { command: "review finished", labels: ["reviewed"]})
    end

    it "#description should include labels" do
      expect(@responder.description).to eq("Label issue with: reviewed")
    end
  end
end