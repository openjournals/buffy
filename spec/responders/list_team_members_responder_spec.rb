require_relative "../spec_helper.rb"

describe ListTeamMembersResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: { bot_github_user: "botsci" }}, { command: "list editors", team_id: 12345 }) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci list editors")
      expect(@responder.event_regex).to match("@botsci list editors.")
      expect(@responder.event_regex).to match("@botsci list editors  \r\n")
      expect(@responder.event_regex).to_not match("```@botsci list editors")
      expect(@responder.event_regex).to_not match("@botsci list editors  \r\n more")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { command: "list editors", team_id: 12345 })
      @team_members = ["user1", "user2"]
      disable_github_calls_for(@responder)
    end

    it "should respond with a erb template to github" do
      team_members = ["user1", "user2"]
      expect(@responder).to receive(:team_members).once.with(12345).and_return(@team_members)

      expected_locals = { heading: "", team_members: @team_members }
      expect(@responder).to receive(:respond_template).once.with(:list_team_members, expected_locals)
      @responder.process_message("@botsci list editors")
    end

    it "should allow to customize heading" do
      @responder.params[:heading] = "Current editors"
      expect(@responder).to receive(:team_members).once.with(12345).and_return(@team_members)

      expected_locals = { heading: "Current editors", team_members: @team_members }
      expect(@responder).to receive(:respond_template).once.with(:list_team_members, expected_locals)
      @responder.process_message("@botsci list editors")
    end

    it "should allow to customize description" do
      expect(@responder.description).to eq("Replies to 'list editors'")

      @responder.params[:description] = "List current editors"
      expect(@responder.description).to eq("List current editors")
    end
  end
end
