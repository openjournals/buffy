require_relative "../../spec_helper.rb"

describe Ropensci::ApproveResponder do

  subject do
    described_class
  end

  before do
    settings = { env: {bot_github_user: "ropensci-review-bot"} }
    params = { add_labels: ["approved!"], remove_labels: ["pending-approval!"] }
    @responder = subject.new(settings, params)
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@ropensci-review-bot approve")
      expect(@responder.event_regex).to match("@ropensci-review-bot approve package-name")
      expect(@responder.event_regex).to match("@ropensci-review-bot approve package.name")
      expect(@responder.event_regex).to match("@ropensci-review-bot approve package-name  \r\n")
      expect(@responder.event_regex).to_not match("@ropensci-review-bot approve package-name. another-command")
      expect(@responder.event_regex).to_not match("@ropensci-review-bot approve package-name\r\nanother-command")
    end
  end

  describe "#process_message" do
    before do
      @msg = "@ropensci-review-bot approve great-package"
      @responder.match_data = @responder.event_regex.match(@msg)
      @issue_body = "... <!--date-accepted--><!--end-date-accepted--> ..." +
                    "... Reviewers: <!--reviewers-list-->@maelle, @mpadge<!--end-reviewers-list--> ..."
      disable_github_calls_for(@responder)
      @responder.context = OpenStruct.new(issue_id: 33,
                                          issue_author: "opener",
                                          repo: "openjournals/testing-approval",
                                          sender: "author")
    end

    it "should verify presence of package name" do
      msg = "@ropensci-review-bot approve"
      @responder.match_data = @responder.event_regex.match(msg)
      expect(@responder).to receive(:respond).with("Could not approve. Please, specify the name of the package.")
      @responder.process_message(msg)
    end

    it "should add value for Date accepted" do
      acceptance_date = Time.now.strftime("%Y-%m-%d")
      expect(@responder).to receive(:update_or_add_value).with("date-accepted", acceptance_date, append: false, heading: "Date accepted")

      allow(@responder).to receive(:issue_body).and_return(@issue_body)
      @responder.process_message(@msg)
    end

    it "should reply if template is present" do
      @responder.params[:template_file] = "approved.md"
      expect(@responder).to receive(:respond_external_template).with("approved.md", @responder.locals)

      allow(@responder).to receive(:issue_body).and_return(@issue_body)
      @responder.process_message(@msg)
    end

    it "should not reply if template is not present" do
      @responder.params[:template_file] = nil
      expect(@responder).to_not receive(:respond_external_template)

      allow(@responder).to receive(:issue_body).and_return(@issue_body)
      @responder.process_message(@msg)
    end

    it "should create an AirtableWorker job" do
      expect(Ropensci::AirtableWorker).to receive(:perform_async).
                                          with("clear_assignments",
                                               @responder.params.transform_keys(&:to_s),
                                               @responder.locals.transform_keys(&:to_s),
                                               { "reviewers" => ["@maelle", "@mpadge"] })

      allow(@responder).to receive(:issue_body).and_return(@issue_body)
      @responder.process_message(@msg)
    end

    it "should process labels" do
      expect(@responder).to receive(:process_labeling)
      expect(@responder.labels_to_add).to eq(["approved!"])
      expect(@responder.labels_to_remove).to eq(["pending-approval!"])

      allow(@responder).to receive(:issue_body).and_return(@issue_body)
      @responder.process_message(@msg)
    end

    it "should create a job to create new team" do
      expect(Ropensci::ApprovedPackageWorker).to receive(:perform_async).
                                                 with("new_team",
                                                      @responder.params.transform_keys(&:to_s),
                                                      @responder.locals.transform_keys(&:to_s),
                                                      { "team_name" => "great-package" })

      allow(@responder).to receive(:issue_body).and_return(@issue_body)
      @responder.process_message(@msg)
    end

    it "should close issue" do
      expect(@responder).to receive(:close_issue)

      allow(@responder).to receive(:issue_body).and_return(@issue_body)
      @responder.process_message(@msg)
    end

    describe "with submission-type = stats" do
      before do
        @issue_body = "... <!--submission-type-->stats<!--end-submission-type--> ..."
      end

      it "should add statsgrade label" do
        @issue_body += "... <!--statsgrade-->silver<!--end-statsgrade--> ..."
        allow(@responder).to receive(:issue_body).and_return(@issue_body)
        expect(@responder).to_not receive(:respond).with("Please add a grade (bronze/silver/gold) before approval.")
        expect(Ropensci::StatsGradesWorker).to receive(:perform_async).
                                                 with("label",
                                                      @responder.locals,
                                                      { "stats_badge_url" => nil})

        @responder.process_message(@msg)
      end

      it "should pass stats_badge_url param if present" do
        @issue_body += "... <!--statsgrade-->silver<!--end-statsgrade--> ..."
        allow(@responder).to receive(:issue_body).and_return(@issue_body)
        @responder.params[:stats_badge_url] = "http://ropensci.test/stats_badges:8000"
        expect(@responder).to_not receive(:respond).with("Please add a grade (bronze/silver/gold) before approval.")
        expect(Ropensci::StatsGradesWorker).to receive(:perform_async).
                                                 with("label",
                                                      @responder.locals,
                                                      { "stats_badge_url" => "http://ropensci.test/stats_badges:8000"})

        @responder.process_message(@msg)
      end

      it "should return if statsgrade is not set" do
        allow(@responder).to receive(:issue_body).and_return(@issue_body)
        expect(@responder).to receive(:respond).with("Please add a grade (bronze/silver/gold) before approval.")
        @responder.process_message(@msg)
      end

      it "should return if statsgrade is not a valid value" do
        @issue_body += "... <!--statsgrade-->lead<!--end-statsgrade--> ..."
        allow(@responder).to receive(:issue_body).and_return(@issue_body)
        expect(@responder).to receive(:respond).with("Please add a grade (bronze/silver/gold) before approval.")
        @responder.process_message(@msg)
      end
    end
  end
end
