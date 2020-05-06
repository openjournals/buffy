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
      expect(@responder.event_regex).to_not match("assign @xuanxu as reviewer 2")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as editor")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as reviewer")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({bot_github_user: 'botsci'}, {})
      disable_github_calls_for(@responder)

      @msg = "@botsci assign @arfon as reviewer 3"
      @responder.match_data = @responder.event_regex.match(@msg)

      @issue = OpenStruct.new({ body: "...Reviewer list: 3: <!--reviewer-3--> Pending <!--end-reviewer-3--> ..." })
      allow(@responder).to receive(:issue).and_return(@issue)

      @context = OpenStruct.new({ repo: "buffy/test", issue_id: 1 })
    end

    it "should update the body of the issue" do
      expected_new_body = "...Reviewer list: 3: <!--reviewer-3--> @arfon <!--end-reviewer-3--> ..."
      expect(@responder).to receive(:update_issue).with(@context, { body: expected_new_body })
      @responder.process_message("Hello @botsci", @context)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("Reviewer 3 assigned!", @context)
      @responder.process_message("Hello @botsci", @context)
    end
  end
end
