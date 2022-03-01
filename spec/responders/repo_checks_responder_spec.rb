require_relative "../spec_helper.rb"

describe RepoChecksResponder do

  before do
    settings = { env: { bot_github_user: "botsci" }}
    @responder = RepoChecksResponder.new(settings, {})
    @responder.context = OpenStruct.new(issue_body: "Test Review\n\n ... description ...")
    @responder.context.issue_body +=  "<!--target-repository-->http://repo.url<!--end-target-repository-->"
    disable_github_calls_for(@responder)
  end

  describe "listening" do

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci check repository")
      expect(@responder.event_regex).to match("@botsci check repository    \r\n")
      expect(@responder.event_regex).to match("@botsci check repository\r\nmore")
      expect(@responder.event_regex).to match("@botsci check repository from branch custom-branch")
      expect(@responder.event_regex).to match("@botsci check repository from branch custom/branch")
      expect(@responder.event_regex).to match("@botsci check repository from branch development    \r\n")
      expect(@responder.event_regex).to_not match("@botsci check repository from branch ")
    end
  end

  describe "#process_message" do
    let(:expected_locals) { {bot_name: "botsci", issue_author: nil, issue_id: nil, repo: nil, sender: nil} }

    it "should respond an error message if no url" do
      @responder.params[:url_field] = "url"
      expect(@responder).to receive(:respond).with("I couldn't find the URL for the target repository")
      @responder.process_message("@botsci check repository")
    end

    it "should call RepoChecksWorker" do
      expected_url = "http://repo.url"
      expected_branch = ""
      expected_checks = nil

      expect(@responder).to_not receive(:respond)
      expect(RepoChecksWorker).to receive(:perform_async).with(expected_locals, expected_url, expected_branch, expected_checks)
      @responder.process_message("@botsci check repository")
    end

    it "should call RepoChecksWorker with custom branch" do
      expected_url = "http://repo.url"
      expected_branch = "custom-branch"
      expected_locals_with_branch = expected_locals.merge({match_data_1: "custom-branch"})
      expected_checks = nil

      msg = "@botsci check repository from branch custom-branch"
      @responder.match_data = @responder.event_regex.match(msg)

      expect(@responder).to_not receive(:respond).with("I couldn't find the URL for the target repository")
      expect(RepoChecksWorker).to receive(:perform_async).with(expected_locals_with_branch, expected_url, expected_branch, expected_checks)
      @responder.process_message(msg)
    end

    it "should call RepoChecksWorker with the checks from params" do
      expected_url = "http://repo.url"
      expected_branch = ""
      expected_checks = ["license", "statement of need"]

      @responder.params = { checks: ["license", "statement of need"] }

      expect(@responder).to_not receive(:respond).with("I couldn't find the URL for the target repository")
      expect(RepoChecksWorker).to receive(:perform_async).with(expected_locals, expected_url, expected_branch, expected_checks)
      @responder.process_message("@botsci check repository")
    end
  end
end