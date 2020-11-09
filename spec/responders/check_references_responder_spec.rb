require_relative "../spec_helper.rb"

describe CheckReferencesResponder do

  before do
    settings = { bot_github_user: "botsci" }
    @responder = CheckReferencesResponder.new(settings, {})
    @responder.context = OpenStruct.new(issue_body: "Test Review\n\n ... description ...")
    disable_github_calls_for(@responder)
  end

  describe "listening" do

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci check references")
      expect(@responder.event_regex).to match("@botsci check references    \r\n")
      expect(@responder.event_regex).to match("@botsci check references from branch custom-branch")
      expect(@responder.event_regex).to match("@botsci check references from branch development    \r\n")
      expect(@responder.event_regex).to_not match("@botsci check references from branch ")
    end
  end

  describe "#url" do

    it "should be empty if not URL found" do
      expect(@responder.url).to be_empty
    end

    it "should use target-repository as the default value for url_field" do
      @responder.context.issue_body +=  "<!--target-repository-->" +
                                        "http://software-to-review.test/git_repo" +
                                        "<!--end-target-repository-->"
      expect(@responder.url).to eq("http://software-to-review.test/git_repo")
    end

    it "should use the settings value for url_field if present" do
      @responder.context.issue_body +=  "<!--target-repository-->" +
                                        "http://software-to-review.test/git_repo" +
                                        "<!--end-target-repository-->" +
                                        "<!--paper-url-->https://custom-url.test<!--end-paper-url-->"
      @responder.params = { url_field: "paper-url" }
      expect(@responder.url).to eq("https://custom-url.test")
    end
  end

  describe "#branch" do
    it "should be nil if no branch found" do
      @responder.match_data = nil
      expect(@responder.branch).to be_nil
    end

    it "should use branch as the default value for branch_field" do
      @responder.context.issue_body +=  "<!--branch-->dev<!--end-branch-->"
      expect(@responder.branch).to eq("dev")
    end

    it "should use the settings value for branch_field if present" do
      @responder.context.issue_body +=  "<!--branch-->dev<!--end-branch-->\n" +
                                        "<!--review-branch-->paper<!--end-review-branch-->\n"
      @responder.params = { branch_field: "review-branch" }
      expect(@responder.branch).to eq("paper")

    end

    it "branch name in command should take precedence over value in the body of the issue" do
      @responder.context.issue_body +=  "<!--branch-->dev<!--end-branch-->"
      command = "@botsci check references from branch custom-branch"
      @responder.match_data = @responder.event_regex.match(command)

      expect(@responder.branch).to eq("custom-branch")
    end
  end

  describe "#process_message" do
    let(:expected_locals) { {bot_name: "botsci", issue_id: nil, repo: nil, sender: nil} }

    it "should respond an error message if no url" do
      expect(@responder).to receive(:respond).with("I couldn't find URL for the target repository")
      @responder.process_message("@botsci check references")
    end

    it "should call DOIWorker" do
      @responder.context.issue_body +=  "<!--target-repository-->PAPERURL<!--end-target-repository-->"
      expected_url = "PAPERURL"
      expected_branch = nil

      expect(@responder).to_not receive(:respond).with("I couldn't find URL for the target repository")
      expect(DOIWorker).to receive(:perform_async).with(expected_locals, expected_url, expected_branch)
      @responder.process_message("@botsci check references")
    end

    it "should call DOIWorker with custom branch" do
      @responder.context.issue_body +=  "<!--target-repository-->http://test.ing<!--end-target-repository-->"
      expected_url = "http://test.ing"
      expected_branch = "custom-branch"
      msg = "@botsci check references from branch custom-branch"
      @responder.match_data = @responder.event_regex.match(msg)

      expect(@responder).to_not receive(:respond).with("I couldn't find URL for the target repository")
      expect(DOIWorker).to receive(:perform_async).with(expected_locals, expected_url, expected_branch)
      @responder.process_message(msg)
    end
  end
end