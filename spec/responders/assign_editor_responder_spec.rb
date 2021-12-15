require_relative "../spec_helper.rb"

describe AssignEditorResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci assign @arfon as editor")
      expect(@responder.event_regex).to match("@botsci assign @xuanxu as editor   \r\n")
      expect(@responder.event_regex).to match("@botsci assign me as editor")
      expect(@responder.event_regex).to_not match("assign @xuanxu as editor")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as editor now")
      expect(@responder.event_regex).to_not match("@botsci assign   as editor")
      expect(@responder.event_regex).to_not match("@botsci assign @xuanxu as reviewer")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      @responder.context = OpenStruct.new({ issue_body:"...Submission editor: <!--editor-->Pending<!--end-editor--> ..." })
      disable_github_calls_for(@responder)

      @msg = "@botsci assign @arfon as editor"
      @responder.match_data = @responder.event_regex.match(@msg)
    end

    it "should update editor in the body of the issue" do
      expected_new_body = "...Submission editor: <!--editor-->@arfon<!--end-editor--> ..."
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
      @responder.process_message(@msg)
    end

    it "should not add editor as collaborator by default" do
      expect(@responder).to_not receive(:add_collaborator)
      @responder.process_message(@msg)
    end

    it "should add editor as collaborator if params[:add_as_collaborator] is true" do
      expect(@responder).to receive(:add_collaborator).with("@arfon")
      @responder.params = {add_as_collaborator: true}
      @responder.process_message(@msg)
    end

    it "should replace editor as assignee by default" do
      expect(@responder).to receive(:read_from_body).once.and_return("@other_editor")
      expect(@responder).to receive(:add_assignee).with("@arfon")
      expect(@responder).to receive(:remove_assignee).with("@other_editor")
      @responder.process_message(@msg)
    end

    it "should not remove assignee if no previous editor present" do
      expect(@responder).to receive(:read_from_body).once.and_return("Pending")
      expect(@responder).to receive(:add_assignee).with("@arfon")
      expect(@responder).to_not receive(:remove_assignee)
      @responder.process_message(@msg)
    end

    it "should not replace editor as assignee if params[:add_as_assignee] is false" do
      expect(@responder).to receive(:read_from_body).once.and_return("@other_editor")
      expect(@responder).to_not receive(:replace_assignee)
      expect(@responder).to_not receive(:add_assignee)
      expect(@responder).to_not receive(:remove_assignee)
      @responder.params = {add_as_assignee: false}
      @responder.process_message(@msg)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("Assigned! @arfon is now the editor")
      @responder.process_message(@msg)
    end

    it "should process labels" do
      expect(@responder).to receive(:process_labeling)
      @responder.process_message(@msg)
    end

    it "should not process external call if not configured" do
      expect(@responder).to_not receive(:process_external_service)
      @responder.process_message(@msg)
    end

    it "should process external call" do
      external_call = { url: "https://theoj.org" ,method: "post", query_params: { secret: "A1234567890Z" }, silent: true}
      @responder.params[:external_call] = external_call
      expected_locals = @responder.locals.merge({ editor: "@arfon" })
      expect(@responder).to receive(:process_external_service).with(external_call, expected_locals)

      @responder.process_message(@msg)
    end

    it "should understand 'assign me'" do
      msg = "@botsci assign me as editor"
      @responder.context.sender = "xuanxu"
      @responder.match_data = @responder.event_regex.match(msg)
      expect(@responder).to receive(:respond).with("Assigned! @xuanxu is now the editor")
      @responder.process_message(msg)
    end
  end
end
