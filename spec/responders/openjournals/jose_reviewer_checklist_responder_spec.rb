require_relative "../../spec_helper.rb"

describe Openjournals::JoseReviewerChecklistResponder do

 subject do
    described_class
  end

  before do
    @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci generate my checklist")
      expect(@responder.event_regex).to match("@botsci generate my checklist.")
      expect(@responder.event_regex).to match("@botsci generate my checklist   \r\n")
      expect(@responder.event_regex).to match("@botsci generate my checklist   \r\nmore")
      expect(@responder.event_regex).to_not match("@botsci generate my checklist for @arfon.")
      expect(@responder.event_regex).to_not match("@botsci generate my checkl")
    end
  end

  describe "#process_message" do
    before do
      @responder.context = OpenStruct.new(sender: "reviewer1",
                                          issue_id: 5,
                                          issue_author: "opener",
                                          repo: "openjournals/buffy",
                                          comment_id: 111222,
                                          issue_body: "Test Submission\n\n ... description ... \n\n" +
                                                      "<!--author-handle-->@submitter<!--end-author-handle-->\n" +
                                                      "<!--target-repository-->https://target.re.po/sitory<!--end-target-repository-->\n" +
                                                      "<!--reviewers-list-->@reviewer1, @reviewer2<!--end-reviewers-list-->")
      @msg = "@botsci generate my checklist"
      disable_github_calls_for(@responder)

      @expected_locals = { issue_id: 5,
                           issue_author: "opener",
                           bot_name: "botsci",
                           repo: "openjournals/buffy",
                           sender: "reviewer1",
                           "author-handle" => "@submitter",
                           "target-repository" => "https://target.re.po/sitory"
                         }
    end

    context "generate checklist command" do
      it "should add default checklist for reviewer" do
        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist_software.md", @expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)
        expect(@responder).to_not receive(:respond)
        @responder.process_message(@msg)
      end

      it "should add software checklist for reviewer" do
        @responder.context[:issue_body] += "\n<!--paper-kind-->software<!--end-paper-kind-->"

        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist_software.md", @expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)
        expect(@responder).to_not receive(:respond)
        @responder.process_message(@msg)
      end

      it "should add learning module checklist for reviewer" do
        @responder.context[:issue_body] += "\n<!--paper-kind-->learning module<!--end-paper-kind-->"

        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist_learning_module.md", @expected_locals).and_return(expected_checklist)
        expect(@responder).to receive(:update_comment).with(111222, expected_checklist)
        expect(@responder).to_not receive(:respond)
        @responder.process_message(@msg)
      end

      it "should be case insensitive for the reviewer's username" do
        @responder.context[:sender] = "ReVIEwer1"

        expected_locals = @expected_locals.dup
        expected_locals[:sender] = "ReVIEwer1"

        expected_checklist = "Checklist for @ReVIEwer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist_software.md", expected_locals).and_return(expected_checklist)
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
        expected_checklist = "Checklist for @reviewer1 \n[] A"

        expect(@responder).to receive(:render_external_template).with("reviewer_checklist_software.md", @expected_locals).and_return(expected_checklist)
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
    responder = subject.new({env: {bot_github_user: "botsci"}}, {command: "create check-list"})

    expect(responder.event_regex).to match("@botsci create check-list")
    expect(responder.event_regex).to_not match("@botsci generate my checklist")
  end
end
