require_relative "../spec_helper.rb"

describe CloseIssueCommandResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({ bot_github_user: "botsci" }, { command: "reject" }) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci reject")
      expect(@responder.event_regex).to match("@botsci reject   \r\n")
      expect(@responder.event_regex).to_not match("@botsci reject publication")
      expect(@responder.event_regex).to_not match("@botsci rejec")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({ bot_github_user: "botsci" },
                               { name: "review_ok",
                                 command: "reject",
                                 labels: ["rejected"] })
      disable_github_calls_for(@responder)

      @msg = "@botsci reject"
    end

    it "should close the issue" do
      expect(@responder).to receive(:close_issue)
      @responder.process_message(@msg)
    end

    it "should label issue with defined labels" do
      expect(@responder).to receive(:close_issue).with({labels: ["rejected"]})
      @responder.process_message(@msg)
    end
  end

  describe "misconfiguration" do
    it "should raise error if command is missing from config" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, {})
      }.to raise_error "Configuration Error in CloseIssueCommandResponder: No value for command."
    end

    it "should raise error if command is empty" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { command: "    " })
      }.to raise_error "Configuration Error in CloseIssueCommandResponder: No value for command."
    end
  end

  describe "documentation" do
    before do
      @responder = subject.new({ bot_github_user: "botsci" }, { command: "reject submission" })
    end

    it "#example_invocation shows the custom command" do
       expect(@responder.example_invocation).to eq("@botsci reject submission")
    end

    it "#description should not include labels" do
      expect(@responder.description).to eq("Close the issue")
    end

    it "#description should include labels if present" do
      @responder.params[:labels] = ["rejected", "no-published"]
      expect(@responder.description).to eq("Label the issue with: [rejected, no-published] and close it.")
    end
  end
end
