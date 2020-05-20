require_relative "../spec_helper.rb"

describe AssignEditorResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({bot_github_user: 'botsci'}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci assign @arfon as editor")
      expect(@responder.event_regex).to match("@botsci assign @xuanxu as editor   \r\n")
      expect(@responder.event_regex).to_not match("assign @xuanxu as editor")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as editor now")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as reviewer")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({ bot_github_user: 'botsci' }, {})
      disable_github_calls_for(@responder)

      @msg = "@botsci assign @arfon as editor"
      @responder.match_data = @responder.event_regex.match(@msg)

      issue = OpenStruct.new({ body: "...Submission editor: <!--editor-->Pending<!--end-editor--> ..." })
      allow(@responder).to receive(:issue).and_return(issue)
    end

    it "should update editor in the body of the issue" do
      expected_new_body = "...Submission editor: <!--editor-->@arfon<!--end-editor--> ..."
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
      @responder.process_message(@msg)
    end

    it "should add editor as collaborator" do
      expect(@responder).to receive(:add_collaborator).with("@arfon")
      @responder.process_message(@msg)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("Assigned! @arfon is now the editor")
      @responder.process_message(@msg)
    end
  end
end
