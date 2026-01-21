require_relative "../../spec_helper.rb"

describe Openjournals::ReviewerChecklistsResponder do

  subject do
    described_class
  end

  before do
    settings = { env: {bot_github_user: "editorialbot"} }
    @responder = subject.new(settings, {})
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@editorialbot generate my checklist")
      expect(@responder.event_regex).to match("@editorialbot generate my checklist.")
      expect(@responder.event_regex).to match("@editorialbot generate my checklist   \r\n")
      expect(@responder.event_regex).to match("@editorialbot generate my checklist   \r\nmore")
      expect(@responder.event_regex).to_not match("@editorialbot generate my checklist for @arfon.")
      expect(@responder.event_regex).to_not match("@editorialbot generate my checkl")
    end
  end

    describe "#process_message" do
    before do
      @responder.context = OpenStruct.new(issue_id: 5,
                                          issue_author: "opener",
                                          issue_title: "New paper",
                                          issue_labels: [{"name" => "test"}],
                                          repo: "openjournals/buffy",
                                          comment_id: 111222,
                                          issue_body: "Test Submission\n\n ... description ... \n\n" +
                                                      "<!--author-handle-->@submitter<!--end-author-handle-->\n" +
                                                      "<!--reviewers-list-->@reviewer1, @reviewer2<!--end-reviewers-list-->")
      @msg = "@editorialbot generate my checklist"
      disable_github_calls_for(@responder)
    end

    context "generate checklist command" do
      it "should add user checklist for reviewer" do
        @responder.context[:sender] = "reviewer1"

        expected_locals = { issue_id: 5, issue_author: "opener", bot_name: "editorialbot", issue_title: "New paper", repo: "openjournals/buffy", sender: "reviewer1" }
        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist.md", expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)
        expect(@responder).to_not receive(:respond)
        @responder.process_message(@msg)
      end

      it "should use pre-2026 checklist if issue is labeled" do
        @responder.context[:sender] = "reviewer1"
        @responder.context.issue_labels << {"name" => "pre-2026-submission"}

        expected_locals = { issue_id: 5, issue_author: "opener", bot_name: "editorialbot", issue_title: "New paper", repo: "openjournals/buffy", sender: "reviewer1" }
        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist_pre2026.md", expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)
        expect(@responder).to_not receive(:respond)
        @responder.process_message(@msg)
      end


      it "should be case insensitive for the reviewer's username" do
        @responder.context[:sender] = "ReVIEwer1"

        expected_locals = { issue_id: 5, issue_author: "opener", issue_title: "New paper", bot_name: "editorialbot", repo: "openjournals/buffy", sender: "ReVIEwer1" }
        expected_checklist = "Checklist for @ReVIEwer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist.md", expected_locals).and_return(expected_checklist)
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
        @responder.context[:sender] = "reviewer1"

        expected_locals = { issue_id: 5, issue_author: "opener", issue_title: "New paper", bot_name: "editorialbot", repo: "openjournals/buffy", sender: "reviewer1" }
        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist.md", expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)


        @link1 = "<!--checklist-for-reviewer1-->\n📝 [Checklist for @reviewer1](https://github.com/openjournals/buffy/issues/5#issuecomment-111222)\n<!--end-checklist-for-reviewer1-->"
        @link2 = "<!--checklist-for-reviewer2-->\n📝 [Checklist for @reviewer2](https://github.com/openjournals/buffy/issues/5#issuecomment-222222)\n<!--end-checklist-for-reviewer2-->"
      end

      it "should not add link to checklist if no checklist-comments mark" do
        expect(@responder).to_not receive(:update_value)
        @responder.process_message(@msg)
      end

      it "should add link to the issue's text" do
        @responder.context[:issue_body] += "<!--checklist-comments--><!--end-checklist-comments-->"

        expect(@responder).to receive(:update_value).with("checklist-comments", "\n#{@link1}\n")
        @responder.process_message(@msg)
      end

      it "should add link to existing checklist" do
        @responder.context[:issue_body] += "<!--checklist-comments-->#{@link2}<!--end-checklist-comments-->"

        expect(@responder).to receive(:update_value).with("checklist-comments", "\n#{@link2}\n#{@link1}\n")
        @responder.process_message(@msg)
      end

      it "should update links to checklist in the issue's text" do
        previous_link = "<!--checklist-for-reviewer1-->Whatever<!--end-checklist-for-reviewer1-->"
        @responder.context[:issue_body] += "<!--checklist-comments--><!--end-checklist-comments-->"

        expect(@responder).to receive(:update_value).with("checklist-comments", "\n#{@link1}\n")
        @responder.process_message(@msg)
      end
    end
  end

  it "command is customizable" do
    responder = subject.new({env: {bot_github_user: "editorialbot"}}, {command: "create check-list"})

    expect(responder.event_regex).to match("@editorialbot create check-list")
    expect(responder.event_regex).to_not match("@editorialbot generate my checklist")
  end

end