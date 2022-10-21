require_relative "../spec_helper.rb"

describe RemindersResponder do

  before do
    settings = { env: { bot_github_user: "botsci" }}
    @responder = RemindersResponder.new(settings, {})
    @responder.context = OpenStruct.new(issue_body: "", sender: "editor21")
    disable_github_calls_for(@responder)
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci remind @reviewer33 in 2 weeks")
      expect(@responder.event_regex).to match("@botsci remind @reviewer33 in 1 month    ")
      expect(@responder.event_regex).to match("@botsci remind @reviewer33 in 1 month    \r\n more")
    end
  end

  describe "#process_message" do
    before do
      @responder.context.issue_body = "<!--reviewers-list-->@reviewer33, @reviewer42<!--end-reviewers-list-->" +
                                      "<!--author-handle-->@author<!--end-author-handle-->"
    end

    it "should respond an error message if user is not an author, reviewer or the sender" do
      msg = "@botsci remind @wrongperson in 2 weeks"
      @responder.match_data = @responder.event_regex.match(msg)
      expect(@responder).to receive(:respond).with("@wrongperson doesn't seem to be a reviewer or author for this submission.")

      @responder.process_message(msg)
    end

    it "should respond an error message if incorrect time format" do
      msg = "@botsci remind @reviewer42 in some time"
      @responder.match_data = @responder.event_regex.match(msg)
      expect(@responder).to receive(:respond).with("I don't recognize this description of time: 'some' 'time'.")

      @responder.process_message(msg)
    end

    it "should respond success message and schedule worker run for the sender" do
      msg = "@botsci remind @editor21 in 5 weeks"
      @responder.match_data = @responder.event_regex.match(msg)
      in_five_weeks = Chronic.parse("in 5 weeks")
      expect(@responder).to receive(:target_time).with("5", "weeks").and_return(in_five_weeks)
      expected_msg = ":wave: @editor21, please take a look at the state of the submission (this is an automated reminder)."
      expect(AsyncMessageWorker).to receive(:perform_at).with(in_five_weeks, @responder.locals, expected_msg)
      expect(ReviewReminderWorker).to_not receive(:perform_at)
      expect(@responder).to receive(:respond).with("Reminder set for @editor21 in 5 weeks")

      @responder.process_message(msg)
    end

    it "should respond success message and schedule worker run for 'me'" do
      msg = "@botsci remind me in 15 days"
      @responder.match_data = @responder.event_regex.match(msg)
      in_15_days = Chronic.parse("in 5 weeks")
      expect(@responder).to receive(:target_time).with("15", "days").and_return(in_15_days)
      expected_msg = ":wave: @editor21, please take a look at the state of the submission (this is an automated reminder)."
      expect(AsyncMessageWorker).to receive(:perform_at).with(in_15_days, @responder.locals, expected_msg)
      expect(ReviewReminderWorker).to_not receive(:perform_at)
      expect(@responder).to receive(:respond).with("Reminder set for @editor21 in 15 days")

      @responder.process_message(msg)
    end

    it "should respond success message and schedule worker run" do
      msg = "@botsci remind @reviewer42 in 3 weeks"
      @responder.match_data = @responder.event_regex.match(msg)
      expect(ReviewReminderWorker).to receive(:perform_at)
      expect(@responder).to receive(:respond).with("Reminder set for @reviewer42 in 3 weeks")

      @responder.process_message(msg)
    end

    it "should call ReviewReminderWorker with scheduling and proper info" do
      msg = "@botsci remind @author in 4 days"
      @responder.match_data = @responder.event_regex.match(msg)

      in_four_days = Chronic.parse("in 4 days")
      expect(@responder).to receive(:target_time).with("4", "days").and_return(in_four_days)

      expect(ReviewReminderWorker).to receive(:perform_at).with(in_four_days, @responder.locals, "@author", true)
      @responder.process_message(msg)
    end
  end

  describe "configurable targets" do
    before do
      @responder.context.issue_body = "<!--reviewers-list-->@reviewer33, @reviewer42<!--end-reviewers-list-->" +
                                      "<!--author-handle-->@author<!--end-author-handle-->" +
                                      "<!--author1-->@author1<!--end-author1-->" +
                                      "<!--author2-->@author2<!--end-author2-->" +
                                      "<!--extra-reviewer-->@extra-reviewer<!--end-extra-reviewer-->"
    end

    it "targets has default values for reviewers, authors and sender" do
      @responder.params = {}
      expect(@responder.targets).to eq(["@author", "@reviewer33", "@reviewer42", "@editor21"])
    end

    it "use default value if no custom reviewers value set" do
      @responder.params = {}
      expect(@responder.reviewers_list).to eq(["@reviewer33", "@reviewer42"])
    end

    it "use default value if no custom authors value set" do
      @responder.params = {}
      expect(@responder.authors_list).to eq(["@author"])
    end

    it "use custom value for reviewers" do
      @responder.params = {reviewers: "extra-reviewer"}
      expect(@responder.reviewers_list).to eq(["@extra-reviewer"])
    end

    it "use custom value for authors" do
      @responder.params = {authors: "author1"}
      expect(@responder.authors_list).to eq(["@author1"])
    end

    it "accept array of values for reviewers" do
      @responder.params = {reviewers: ["author2" ,"extra-reviewer"]}
      expect(@responder.reviewers_list).to eq(["@author2", "@extra-reviewer"])
    end

    it "accept array of values for authors" do
      @responder.params = {authors: ["author1" ,"author2"]}
      expect(@responder.authors_list).to eq(["@author1", "@author2"])
    end

    it "targets are uniq" do
      @responder.params = {reviewers: ["reviewers-list", "extra-reviewer", "author2"], authors: ["author1" ,"author2", "extra-reviewer"] }

      expect(@responder.targets).to eq(["@author1", "@author2", "@extra-reviewer", "@reviewer33", "@reviewer42", "@editor21"])
    end
  end
end