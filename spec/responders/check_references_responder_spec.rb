require_relative "../spec_helper.rb"

describe CheckReferencesResponder do

  before do
    settings = { env: { bot_github_user: "botsci" }}
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

  describe "#process_message" do
    let(:expected_locals) { {bot_name: "botsci", issue_id: nil, repo: nil, sender: nil} }

    it "should respond an error message if no url" do
      expect(@responder).to receive(:respond).with("I couldn't find the URL for the target repository")
      @responder.process_message("@botsci check references")
    end

    it "should call DOIWorker" do
      @responder.context.issue_body +=  "<!--target-repository-->PAPERURL<!--end-target-repository-->"
      expected_url = "PAPERURL"
      expected_branch = ""

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