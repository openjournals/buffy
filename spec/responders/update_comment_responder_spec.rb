require_relative "../spec_helper.rb"

describe UpdateCommentResponder do

  subject do
    described_class
  end

  before do
    @responder = subject.new({env: {bot_github_user: "botsci"}}, {command: 'list pre-acceptance tasks',template_file: 'final-checklist.md'})
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci list pre-acceptance tasks")
      expect(@responder.event_regex).to match("@botsci list pre-acceptance tasks.")
      expect(@responder.event_regex).to match("@botsci list pre-acceptance tasks   \r\n")
      expect(@responder.event_regex).to match("@botsci list pre-acceptance tasks   \r\nmore")
      expect(@responder.event_regex).to_not match("@botsci list pre-acceptance tasks for @arfon.")
      expect(@responder.event_regex).to_not match("@botsci list pre-acceptance task")
    end
  end

  describe "#process_message" do
    before do
      @responder.context = OpenStruct.new(issue_id: 5,
                                          issue_author: "opener",
                                          sender: "editor33",
                                          repo: "openjournals/buffy",
                                          comment_id: 111222,
                                          issue_body: "Test Submission\n\n ... description ... \n\n")
      @msg = "@botsci list pre-acceptance tasks"
      disable_github_calls_for(@responder)
    end

    context "#process_message" do
      it "should update original comment" do
        expected_locals = { issue_id: 5, issue_author: "opener", bot_name: "botsci", repo: "openjournals/buffy", sender: "editor33" }
        expected_checklist = "Final tasks: \n[ ] A\n[ ] B"

        expect(@responder).to receive(:render_external_template).with("final-checklist.md", expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)
        expect(@responder).to_not receive(:respond)
        @responder.process_message(@msg)
      end
    end
  end

  it "command is customizable" do
    responder = subject.new({env: {bot_github_user: "botsci"}}, {template_file: 'checklist.md', command: "create check-list"})

    expect(responder.event_regex).to match("@botsci create check-list")
  end

  describe "misconfiguration" do
    it "should raise error if command is missing from config" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      }.to raise_error "Configuration Error in UpdateCommentResponder: No value for command."
    end

    it "should raise error if name is command" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, { command: "    " })
      }.to raise_error "Configuration Error in UpdateCommentResponder: No value for command."
    end

    it "should raise error if template_file is missing from config" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, { command: "do something" })
      }.to raise_error "Configuration Error in UpdateCommentResponder: No value for template_file."
    end

    it "should raise error if name is template_file" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, { command: "do something", template_file: "    " })
      }.to raise_error "Configuration Error in UpdateCommentResponder: No value for template_file."
    end
  end

  describe "documentation" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { command: "do something", template_file: "nice-template.md"})
    end

    it "default description includes template file" do
      expect(@responder.description).to eq("Updates sender's comment with the nice-template.md template")
    end

    it "description is customizable" do
      @responder.params[:description] = "List next steps"
      expect(@responder.description).to eq("List next steps")
    end

    it "#example_invocation should have default sample value" do
      expect(@responder.example_invocation).to eq("@botsci do something")
    end
  end
end
