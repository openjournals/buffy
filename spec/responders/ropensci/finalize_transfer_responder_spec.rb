require_relative "../../spec_helper.rb"

describe Ropensci::FinalizeTransferResponder do

  subject do
    described_class
  end

  before do
    settings = { env: {bot_github_user: "ropensci-review-bot"} }
    @responder = subject.new(settings, {})
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@ropensci-review-bot finalize transfer of package.name")
      expect(@responder.event_regex).to match("@ropensci-review-bot finalize transfer of package-name")
      expect(@responder.event_regex).to match("@ropensci-review-bot finalise transfer of package-name")
      expect(@responder.event_regex).to match("@ropensci-review-bot finalise transfer of package4.5-n.a-m.e")
      expect(@responder.event_regex).to match("@ropensci-review-bot finalize transfer of package-name  \r\n")
      expect(@responder.event_regex).to match("@ropensci-review-bot finalise transfer of package-name. \r\n")
      expect(@responder.event_regex).to_not match("@ropensci-review-bot finalize transfer of package-name. another-command")
      expect(@responder.event_regex).to_not match("@ropensci-review-bot finalize transfer of package-name\r\nanother-command")
    end
  end

  describe "#process_message" do
    before do
      @msg = "@ropensci-review-bot finalize transfer of great-package"
      @responder.match_data = @responder.event_regex.match(@msg)
      disable_github_calls_for(@responder)
      @responder.context = OpenStruct.new(issue_id: 33,
                                          issue_author: "opener",
                                          repo: "openjournals/testing-approval",
                                          sender: "author")
    end

    it "should verify presence of package name" do
      msg = "@ropensci-review-bot finalize transfer of "
      @responder.match_data = @responder.event_regex.match(msg)
      expect(@responder).to receive(:respond).with("Could not finalize transfer: Please, specify the name of the package (should match the name of the team at the rOpenSci org)")
      @responder.process_message(msg)
    end

    it "should verify presence of package author" do
      msg = "@ropensci-review-bot finalize transfer of nice-package"
      @responder.match_data = @responder.event_regex.match(msg)
      @responder.context[:issue_author] = nil
      expect(@responder).to receive(:respond).with("Could not finalize transfer: Could not identify package author")
      @responder.process_message(msg)
    end

    it "should create a job to finalize transfer" do
      expect(Ropensci::ApprovedPackageWorker).to receive(:perform_async).
                                                 with("finalize_transfer",
                                                      @responder.params,
                                                      @responder.locals,
                                                      {"package_author" => "opener", "package_name" => "great-package"})

      @responder.process_message(@msg)
    end
  end
end
