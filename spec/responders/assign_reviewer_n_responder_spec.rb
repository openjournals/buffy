require_relative "../spec_helper.rb"

describe AssignReviewerNResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({bot_github_user: 'botsci'}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci assign @arfon as reviewer 1")
      expect(@responder.event_regex).to match("@botsci assign @xuanxu as reviewer 33B")
      expect(@responder.event_regex).to_not match("@botsci assign   as reviewer 2")
      expect(@responder.event_regex).to_not match("assign @xuanxu as reviewer 2")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as editor")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as reviewer")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({ bot_github_user: 'botsci' }, {})
      disable_github_calls_for(@responder)

      @msg = "@botsci assign @arfon as reviewer 3"
      @responder.match_data = @responder.event_regex.match(@msg)

      issue_body = "...Reviewer list: 3: <!--reviewer-3-->Pending<!--end-reviewer-3--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    it "should update a reviewer the body of the issue" do
      expected_new_body = "...Reviewer list: 3: <!--reviewer-3-->@arfon<!--end-reviewer-3--> ..."
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
      @responder.process_message(@msg)
    end

    it "should add reviewer as collaborator by default" do
      expect(@responder).to receive(:add_collaborator).with("@arfon")
      @responder.process_message(@msg)
    end

    it "should not add reviewer as collaborator if params[:add_as_collaborator] is false" do
      expect(@responder).to_not receive(:add_collaborator).with("@arfon")
      @responder.params = {add_as_collaborator: false}
      @responder.process_message(@msg)
    end

    it "should replace reviewer as assignee by default" do
      expect(@responder).to receive(:read_from_body).once.and_return("@other_reviewer")
      expect(@responder).to receive(:add_assignee).with("@arfon")
      expect(@responder).to receive(:remove_assignee).with("@other_reviewer")
      @responder.process_message(@msg)
    end

    it "should not remove assignee if no previous reviewer present" do
      expect(@responder).to receive(:read_from_body).once.and_return("Pending")
      expect(@responder).to receive(:add_assignee).with("@arfon")
      expect(@responder).to_not receive(:remove_assignee)
      @responder.process_message(@msg)
    end

    it "should not replace reviewer as assignee if params[:add_as_assignee] is false" do
      expect(@responder).to receive(:read_from_body).once.and_return("@other_reviewer")
      expect(@responder).to_not receive(:replace_assignee)
      expect(@responder).to_not receive(:add_assignee)
      expect(@responder).to_not receive(:remove_assignee)
      @responder.params = {add_as_assignee: false}
      @responder.process_message(@msg)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("Reviewer 3 assigned!")
      @responder.process_message(@msg)
    end
  end
end
