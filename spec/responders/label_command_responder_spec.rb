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
                                 labels: ["reviewed", "approved", "pending publication"],
                                 remove: ["pending review", "ongoing"] })
      disable_github_calls_for(@responder)

      @msg = "@botsci recommend publication"
    end

    it "should label issue with defined labels" do
      expect(@responder).to receive(:issue_labels).and_return(["pending review", "ongoing"])
      expect(@responder).to receive(:label_issue).with(["reviewed", "approved", "pending publication"])
      @responder.process_message(@msg)
    end

    it "should remove labels from issue" do
      expect(@responder).to receive(:issue_labels).and_return(["pending review", "ongoing"])
      expect(@responder).to receive(:unlabel_issue).with("pending review")
      expect(@responder).to receive(:unlabel_issue).with("ongoing")
      @responder.process_message(@msg)
    end

    it "should remove only present labels from issue" do
      expect(@responder).to receive(:issue_labels).and_return(["reviewers assigned", "ongoing"])
      expect(@responder).to_not receive(:unlabel_issue).with("pending review")
      expect(@responder).to receive(:unlabel_issue).with("ongoing")
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

    it "should raise error if labels and remove params are missing from config" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "reviewed" })
        @responder.process_message(@msg)
      }.to raise_error "Configuration Error in LabelCommandResponder: No labels specified."
    end

    it "should raise error if labels and remove params are empty" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "reviewed", labels: [], remove: [] })
        @responder.process_message(@msg)
      }.to raise_error "Configuration Error in LabelCommandResponder: No labels specified."
    end

    it "should raise error if labels param is not an array" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "reviewed", labels: "reviewed", remove: [] })
        @responder.process_message(@msg)
      }.to raise_error "Configuration Error in LabelCommandResponder: No labels specified."
    end

    it "should not raise error if only labels present" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci"}, { command: "reviewed", labels: ["review ok"] })
        expect(@responder).to receive(:label_issue).with(["review ok"])
        @responder.process_message(@msg)
      }.to_not raise_error
    end

    it "should not raise error if only remove present" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "reviewed", remove: ["pending-review"] })
        expect(@responder).to receive(:issue_labels).and_return(["pending-review"])
        expect(@responder).to receive(:unlabel_issue).with("pending-review")
        @responder.process_message(@msg)
      }.to_not raise_error
    end
  end

  describe "documentation" do
    before do
      @responder = subject.new({ bot_github_user: "botsci" }, { command: "review finished" })
    end

    it "#description should include only labels" do
      @responder.params[:labels] = ["reviewed"]
      expect(@responder.description).to eq("Label issue with: reviewed")
    end

    it "#description should include only removed labels" do
      @responder.params[:remove] = ["pending-review", "ongoing"]
      expect(@responder.description).to eq("Remove labels: pending-review, ongoing")
    end

    it "#description should include added and removed labels" do
      @responder.params[:labels] = ["accepted"]
      @responder.params[:remove] = ["ongoing review"]
      expect(@responder.description).to eq("Label issue with: accepted. Remove labels: ongoing review")
    end
  end
end