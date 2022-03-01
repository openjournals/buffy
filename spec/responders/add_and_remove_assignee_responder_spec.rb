require_relative "../spec_helper.rb"

describe AddAndRemoveAssigneeResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci add assignee: @arfon")
      expect(@responder.event_regex).to match("@botsci add assignee: @arfon.")
      expect(@responder.event_regex).to match("@botsci remove assignee: @arfon   \r\n more")
      expect(@responder.event_regex).to_not match("remove assignee: @arfon")
      expect(@responder.event_regex).to_not match("@botsci remove assignee: @arfon and others")
      expect(@responder.event_regex).to_not match("@botsci add assignee @arfon")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      @responder.context = OpenStruct.new(repo: "openjournals/joss")
      disable_github_calls_for(@responder)
    end

    context "adding an assignee" do
      before do
        @msg = "@botsci add assignee: @arfon"
        @responder.match_data = @responder.event_regex.match(@msg)
      end

      it "should add user as assignee if posible" do
        expect_any_instance_of(Octokit::Client).to receive(:check_assignee).once.and_return(true)
        expect(@responder).to_not receive(:remove_assignee)
        expect(@responder).to receive(:add_assignee).with("@arfon")
        expect(@responder).to receive(:respond).with("@arfon added as assignee.")
        expect(@responder).to receive(:process_labeling)
        expect(@responder).to_not receive(:process_reverse_labeling)
        @responder.process_message(@msg)
      end

      it "should not add user as assignee if not enough permissions" do
        expect_any_instance_of(Octokit::Client).to receive(:check_assignee).once.and_return(false)
        expect(@responder).to_not receive(:remove_assignee)
        expect(@responder).to_not receive(:add_assignee)
        expect(@responder).to receive(:respond).with("@arfon lacks permissions to be an assignee.")
        expect(@responder).to_not receive(:process_labeling)
        @responder.process_message(@msg)
      end
    end

    context "removing an assignee" do
      before do
        @msg = "@botsci remove assignee: @arfon."
        @responder.match_data = @responder.event_regex.match(@msg)
      end

      it "should remove user from assignees" do
        expect_any_instance_of(Octokit::Client).to_not receive(:check_assignee)
        expect(@responder).to_not receive(:add_assignee)
        expect(@responder).to receive(:remove_assignee).with("@arfon")
        expect(@responder).to receive(:respond).with("@arfon removed from assignees.")
        @responder.process_message(@msg)
      end

      it "should process reverse labeling" do
        expect(@responder).to receive(:process_reverse_labeling)
        @responder.process_message(@msg)
      end
    end
  end
end
