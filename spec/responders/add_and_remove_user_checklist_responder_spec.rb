require_relative "../spec_helper.rb"

describe AddAndRemoveUserChecklistResponder do

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
      expect(@responder.event_regex).to match("@botsci add checklist for @arfon")
      expect(@responder.event_regex).to match("@botsci add checklist for @arfon.")
      expect(@responder.event_regex).to match("@botsci remove checklist for @arfon   \r\n")
      expect(@responder.event_regex).to_not match("remove checklist for @arfon")
      expect(@responder.event_regex).to_not match("@botsci add checklist for @arfon and others")
      expect(@responder.event_regex).to_not match("@botsci add checklist for ")
    end
  end

  describe "#process_message" do
    before do
      @responder.context = OpenStruct.new(issue_id: 5,
                                          issue_author: "opener",
                                          repo: "openjournals/buffy",
                                          sender: "user33",
                                          issue_body: "Test Review\n\n ... description ..." +
                                                      "<!--checklist-for-@xuanxu-->\n " +
                                                      "[ ] this \n [ ] that \n" +
                                                      "<!--end-checklist-for-@xuanxu-->")
      disable_github_calls_for(@responder)
    end

    context "adding a checklist" do
      it "should add user checklist if not already present" do
        msg = "@botsci add checklist for @arfon"
        @responder.match_data = @responder.event_regex.match(msg)

        expected_locals = { issue_id: 5, issue_author: "opener", bot_name: "botsci", repo: "openjournals/buffy", sender: "user33" }
        expected_checklist = "\n<!--checklist-for-@arfon-->" +
                             "\n## Review checklist for @arfon" +
                             "\n[] A" +
                             "\n<!--end-checklist-for-@arfon-->\n"

        expect(@responder).to receive(:render_external_template).with("checklist.md", expected_locals).and_return("[] A")
        expect(@responder).to receive(:append_to_body).with(expected_checklist)
        expect(@responder).to receive(:respond).with("Checklist added for @arfon")
        expect(@responder).to receive(:process_labeling)
        expect(@responder).to_not receive(:process_reverse_labeling)
        @responder.process_message(@msg)
      end

      it "should not add user checklist if already present" do
        msg = "@botsci add checklist for @xuanxu."
        @responder.match_data = @responder.event_regex.match(msg)

        expect(@responder).to receive(:respond).with("There is already a checklist for @xuanxu")
        expect(@responder).to_not receive(:process_labeling)
        @responder.process_message(@msg)
      end
    end

    context "removing a checklist" do
      it "should remove user checklist if present" do
        msg = "@botsci remove checklist for @xuanxu"
        @responder.match_data = @responder.event_regex.match(msg)

        expected_mark = "<!--checklist-for-@xuanxu-->"
        expected_end_mark = "<!--end-checklist-for-@xuanxu-->"
        expect(@responder).to receive(:delete_from_body).with(expected_mark, expected_end_mark, true)
        expect(@responder).to receive(:respond).with("Checklist for @xuanxu removed")
        expect(@responder).to receive(:process_reverse_labeling)
        @responder.process_message(@msg)
      end

      it "should not remove user checklist if not present" do
        msg = "@botsci remove checklist for @arfon"
        @responder.match_data = @responder.event_regex.match(msg)
        expect(@responder).to receive(:respond).with("There is not a checklist for @arfon")
        expect(@responder).to_not receive(:process_labeling)
        @responder.process_message(@msg)
      end
    end
  end
end
