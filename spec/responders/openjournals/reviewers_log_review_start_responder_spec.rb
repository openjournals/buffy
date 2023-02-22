require_relative "../../spec_helper.rb"

describe Openjournals::ReviewersLogReviewStartResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new issues" do
      expect(@responder.event_action).to eq("issues.opened")
    end

    it "should not define regex" do
      expect(@responder.event_regex).to be_nil
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: { bot_github_user: "botsci",
                                       reviewers_api_token: "testTOKEN1234",
                                       reviewers_host_url: "https://reviewers.test"
                                     }}, {})
      @responder.context = OpenStruct.new(issue_title: "[REVIEW]: TestSoftware: a test submission for scientific computation",
                                          issue_id: 3333,
                                          issue_body: "...Reviewers: <!--reviewers-list-->@arfon, @xuanxu<!--end-reviewers-list--> ...")

      disable_github_calls_for(@responder)
    end

    it "should do nothing if issue is not a review" do
      @responder.context[:issue_title] = "[PRE REVIEW]: TestSoftware: a test submission for scientific computation"

      expect(@responder).to_not receive(:list_of_reviewers)
      expect(OJRA::Client).to_not receive(:new)

      @responder.process_message("")
    end

    it "should do nothing if Reviewers API is not configured" do
      @responder.env[:reviewers_api_token] = ""

      expect(@responder.logger).to receive(:warn)
      expect(Faraday).to_not receive(:post)

      @responder.process_message("")
    end

    it "should call reviewers API's assign_reviewers method with all reviewers" do
      expect_any_instance_of(OJRA::Client).to receive(:start_review).with(["@arfon", "@xuanxu"], 3333).and_return(true)

      @responder.process_message("")
    end
  end
end
