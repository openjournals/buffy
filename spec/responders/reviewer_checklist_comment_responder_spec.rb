require_relative "../spec_helper.rb"

describe ReviewerChecklistCommentResponder do

  subject do
    described_class
  end

  before do
    @responder = subject.new({env: {bot_github_user: "botsci"}}, {template_file: 'checklist.md'})
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci generate my checklist")
      expect(@responder.event_regex).to match("@botsci generate my checklist.")
      expect(@responder.event_regex).to match("@botsci generate my checklist   \r\n")
      expect(@responder.event_regex).to_not match("@botsci generate my checklist for @arfon.")
      expect(@responder.event_regex).to_not match("@botsci generate my checkl")
    end
  end

  describe "#process_message" do
    before do
      @responder.context = OpenStruct.new(issue_id: 5,
                                          issue_author: "opener",
                                          repo: "openjournals/buffy",
                                          comment_id: 111222,
                                          issue_body: "Test Submission\n\n ... description ... \n\n" +
                                                      "<!--author-handle-->@submitter<!--end-author-handle-->\n" +
                                                      "<!--reviewers-list-->@reviewer1, @reviewer2<!--end-reviewers-list-->")
      @msg = "@botsci generate my checklist"
      disable_github_calls_for(@responder)
    end

    context "generate checklist command" do
      it "should add user checklist for reviewer" do
        @responder.context[:sender] = "reviewer1"

        expected_locals = { issue_id: 5, issue_author: "opener", bot_name: "botsci", repo: "openjournals/buffy", sender: "reviewer1" }
        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("checklist.md", expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)
        expect(@responder).to_not receive(:respond)
        @responder.process_message(@msg)
      end

      it "should not add user checklist if sender is not a reviewer" do
        @responder.context[:sender] = "nonreviewer"

        expect(@responder).to receive(:respond).with("@nonreviewer I can't do that because you are not a reviewer")
        @responder.process_message(@msg)
      end
    end

    context "checklist links" do
      before do
        expected_locals = { issue_id: 5, issue_author: "opener", bot_name: "botsci", repo: "openjournals/buffy", sender: "reviewer1" }
        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("checklist.md", expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)


        @link1 = "<!--checklist-for-reviewer1-->\n📝 [Checklist for @reviewer1](https://github.com/openjournals/buffy/issues/5#issuecomment-111222)\n<!--end-checklist-for-reviewer1-->"
        @link2 = "<!--checklist-for-reviewer2-->\n📝 [Checklist for @reviewer2](https://github.com/openjournals/buffy/issues/5#issuecomment-222222)\n<!--end-checklist-for-reviewer2-->"
        @checklists_links = "\n#{@link1}\n#{@link2}\n"
      end

      it "should not add link to checklist if no checklist-comments mark" do
        @responder.context[:sender] = "reviewer1"

        expect(@responder).to_not receive(:update_value)
        @responder.process_message(@msg)
      end

      it "should add link to checklist to the issue text" do
        @responder.context[:sender] = "reviewer1"

        @responder.context[:issue_body] += "<!--checklist-comments--><!--end-checklist-comments-->"

        expect(@responder).to receive(:update_value).with("checklist-comments", "\n#{@link1}\n")
        @responder.process_message(@msg)
      end

      it "should update links to checklist in the issue's text" do
        @responder.context[:sender] = "reviewer1"

        @responder.context[:issue_body] += "<!--checklist-comments--><!--end-checklist-comments-->"

        expect(@responder).to receive(:update_value).with("checklist-comments", "\n#{@link1}\n")
        @responder.process_message(@msg)
      end
    end
  end

  it "command is customizable" do
    responder = subject.new({env: {bot_github_user: "botsci"}}, {template_file: 'checklist.md', command: "create check-list"})

    expect(responder.event_regex).to match("@botsci create check-list")
    expect(responder.event_regex).to_not match("@botsci generate my checklist")
  end
end
