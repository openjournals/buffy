require_relative "../spec_helper.rb"

describe ExternalStartReviewResponder do

  subject do
    described_class
  end

  describe "listening" do
    before do
      settings = { env: {bot_github_user: "botsci"} }
      params = { external_call: { url: "http://testing.openjournals.org" }}
      @responder = subject.new(settings, params)
    end

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci start review")
      expect(@responder.event_regex).to match("@botsci start review  ")
      expect(@responder.event_regex).to match("@botsci start review   \r\n other comment \r\n more")
    end
  end

  describe "#process_message" do
    before do
      settings = { env: {bot_github_user: "botsci"} }
      params = { external_call: { url: "http://testing.openjournals.org" }}
      @responder = subject.new(settings, params)
      @responder.context = OpenStruct.new(issue_id: 33,
                                          issue_author: "opener",
                                          issue_title: "[PRE REVIEW]: TesT",
                                          repo: "openjournals/testing",
                                          sender: "xuanxu",
                                          issue_body: "")
      disable_github_calls_for(@responder)
    end

    it "should respond error if no reviewers assigned" do
      @responder.context[:issue_body] = "<!--editor-->@xuanxu<!--end-editor-->"
      expect(@responder).to receive(:respond).with("Can't start a review without reviewers")
      expect(@responder).to_not receive(:process_external_service)
      @responder.process_message("")
    end

    it "should respond error if no editor assigned" do
      @responder.context[:issue_body] = "<!--reviewers-list-->@xuanxu<!--end-reviewers-list-->"
      expect(@responder).to receive(:respond).with("Can't start a review without an editor")
      expect(@responder).to_not receive(:process_external_service)
      @responder.process_message("")
    end

    it "should respond error if issue is a review" do
      @responder.context[:issue_body] = "<!--editor-->@arfon<!--end-editor-->" +
                                        "<!--reviewers-list-->@xuanxu<!--end-reviewers-list-->"
      @responder.context[:issue_title] = "[REVIEW]: TesT"
      expect(@responder).to receive(:respond).with("Can't start a review when the review has already started")
      expect(@responder).to_not receive(:process_external_service)
      @responder.process_message("")
    end

    it "should create ExternalServiceWorker with proper config" do
      @responder.context[:issue_body] = "<!--editor-->@arfon<!--end-editor-->" +
                                        "<!--reviewers-list-->@xuanxu, @karthik<!--end-reviewers-list-->"
      expected_params = {"url" =>"http://testing.openjournals.org"}
      expected_locals = { "bot_name" => "botsci",
                          "editor_login" => "arfon",
                          "editor_username" => "@arfon",
                          "issue_author" => "opener",
                          "issue_title" => "[PRE REVIEW]: TesT",
                          "issue_id" => 33,
                          "repo" => "openjournals/testing",
                          "reviewers_logins" => "xuanxu,karthik",
                          "reviewers_usernames" => ["@xuanxu", "@karthik"],
                          "sender" => "xuanxu" }

      expect(ExternalServiceWorker).to receive(:perform_async).with(expected_params, expected_locals)
      @responder.process_message("")
    end
  end

  describe "misconfiguration" do
    it "should raise error if external_call is missing from config" do
      expect {
        subject.new({env: {bot_github_user: "botsci"}}, { external_call: nil })
      }.to raise_error "Configuration Error in ExternalStartReviewResponder: No value for external_call."
    end
  end

end