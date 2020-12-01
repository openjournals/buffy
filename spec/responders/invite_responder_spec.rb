require_relative "../spec_helper.rb"

describe InviteResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci invite @arfon")
      expect(@responder.event_regex).to match("@botsci invite @xuanxu  \r\n")
      expect(@responder.event_regex).to_not match("@botsci invite @arfon as whatever")
      expect(@responder.event_regex).to_not match("invite @buffy")
      expect(@responder.event_regex).to_not match("@botsci invite ")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      allow(@responder).to receive(:invitations_url).and_return("../invitations")
      allow(@responder).to receive(:is_invited?).and_return(false)
      allow(@responder).to receive(:is_collaborator?).and_return(false)
      allow(@responder).to receive(:add_collaborator).and_return(true)
    end

    it "should respond to github" do
      expected_response = "OK, invitation sent!\n\n@willow_r please accept the invite here: ../invitations"
      expect(@responder).to receive(:respond).once.with(expected_response)

      msg = "@botsci invite @willow_r"
      @responder.match_data = @responder.event_regex.match(msg)
      @responder.process_message(msg)
    end
  end

end
