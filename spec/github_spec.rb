require_relative "./spec_helper.rb"

describe "Github methods" do

  subject do
    settings = Sinatra::IndifferentHash[teams: { editors: 11, reviewers: 22, eics: 33 }]
    params ={ only: ["editors", "eics"] }
    Responder.new(settings, params)
  end

  before do
    subject.context = OpenStruct.new({ repo: "openjournals/buffy", issue_id: 5})
  end

  describe "#github_client" do
    it "should memoize an Octokit Client" do
      expect(Octokit::Client).to receive(:new).once.and_return("whatever")
      subject.github_client
      subject.github_client
    end
  end

  describe "#issue" do
    it "should call proper issue using the Octokit client" do
      expect_any_instance_of(Octokit::Client).to receive(:issue).once.with("openjournals/buffy", 5).and_return("issue")
      subject.issue
      subject.issue
    end
  end

  describe "#bg_respond" do
    it "should add comment to github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:add_comment).once.with("openjournals/buffy", 5, "comment!")
      subject.bg_respond("comment!")
    end
  end

  describe "#label_issue" do
    it "should add labels to github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:add_labels_to_an_issue).once.with("openjournals/buffy", 5, ["reviewed"])
      subject.label_issue(["reviewed"])
    end
  end

  describe "#update_issue" do
    it "should update github issue with received options" do
      expect_any_instance_of(Octokit::Client).to receive(:update_issue).once.with("openjournals/buffy", 5, { body: "new body"})
      subject.update_issue({body: "new body"})
    end
  end

  describe "#is_collaborator?" do
    it "should be true if user is a collaborator" do
      expect_any_instance_of(Octokit::Client).to receive(:collaborator?).twice.with("openjournals/buffy", "xuanxu").and_return(true)
      expect(subject.is_collaborator?("@xuanxu")).to eq(true)
      expect(subject.is_collaborator?("xuanxu")).to eq(true)
    end

    it "should be false if user is not a collaborator" do
      expect_any_instance_of(Octokit::Client).to receive(:collaborator?).twice.with("openjournals/buffy", "xuanxu").and_return(false)
      expect(subject.is_collaborator?("@XuanXu")).to eq(false)
      expect(subject.is_collaborator?("xuanxu")).to eq(false)
    end
  end

  describe "#is_invited?" do
    before do
      invitations = [OpenStruct.new(invitee: OpenStruct.new(login: 'Faith')), OpenStruct.new(invitee: OpenStruct.new(login: 'Buffy'))]
      allow_any_instance_of(Octokit::Client).to receive(:repository_invitations).with("openjournals/buffy").and_return(invitations)
    end

    it "should be true if user has a pending invitation" do
      expect(subject.is_invited?("@BUFfy")).to eq(true)
      expect(subject.is_invited?("buffy")).to eq(true)
    end

    it "should be false if user has not a pending invitation" do
      expect(subject.is_invited?("drusilla")).to eq(false)
    end
  end

  describe "#add_collaborator" do
    it "should add the user to the repo's collaborators" do
      expect_any_instance_of(Octokit::Client).to receive(:add_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.add_collaborator("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:add_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.add_collaborator("@XuanXu")
    end
  end

  describe "#remove_collaborator" do
    it "should remove the user to the repo's collaborators" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.remove_collaborator("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.remove_collaborator("@XuanXu")
    end
  end

  describe "#team_id" do
    context "with valid API access" do
      before do
        teams = [{name: "Editors", id: 372411, description: ""}, {name: "Bots!", id: 111001, slug: "bots"}]
        expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.and_return(teams)
      end

      it "should return team's id if the team exists" do
        expect(subject.team_id("openjournals/editors")).to eq(372411)
      end

      it "should find team by slug" do
        expect(subject.team_id("openjournals/bots")).to eq(111001)
      end

      it "should return nil if the team doesn't exists" do
        expect(subject.team_id("openjournals/nonexistent")).to be_nil
      end
    end

    it "should raise a configuration error for teams with wrong name" do
      expect {
        subject.team_id("wrong-name")
      }.to raise_error "Configuration Error: Invalid team name: wrong-name"
    end

    it "should raise a configuration error if there's not access to the organization" do
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.with("buffy").and_raise(Octokit::Forbidden)

      expect {
        subject.team_id("buffy/whatever")
      }.to raise_error "Configuration Error: No API access to organization: buffy"
    end
  end

  describe "#user_authorized?" do
    it "should return true if user is member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(true)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(33, "sender")

      expect(subject.user_authorized?("sender")).to be_truthy
    end

    it "should return false if user is not member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(false)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(33, "sender").and_return(false)

      expect(subject.user_authorized?("sender")).to be_falsey
    end
  end

  describe "#invitations_url" do
    it "should return the url of the repo's invitations page" do
      expected_url = "https://github.com/openjournals/buffy/invitations"
      expect(subject.invitations_url).to eq(expected_url)
    end
  end

  describe ".get_team_ids" do
    it "should convert all team entries to ids" do
      config = { teams: { editors: 11, eics: "openjournals/eics", nonexistent: "openjournals/nope" } }
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).twice.and_return([{name: "eics", id: 42}])

      expected_response = { editors: 11, eics: 42, nonexistent: nil }
      expect(Responder.get_team_ids(config)). to eq(expected_response)
    end

    it "should find teams by slug" do
      config = { teams: { the_bots: "openjournals/bots" } }
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.and_return([{name: "Rob0tz", id: 111001, slug: "bots"}])

      expected_response = { the_bots: 111001 }
      expect(Responder.get_team_ids(config)). to eq(expected_response)
    end

    it "should raise a configuration error for teams with wrong name" do
      config = { teams: { editors: 11, nonexistent: "wrong-name" } }

      expect {
        Responder.get_team_ids(config)
      }.to raise_error "Configuration Error: Invalid team name: wrong-name"
    end

    it "should raise a configuration error if there's not access to the organization" do
      config = { teams: { the_bots: "openjournals/bots" } }
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.with("openjournals").and_raise(Octokit::Forbidden)

      expect {
        Responder.get_team_ids(config)
      }.to raise_error "Configuration Error: No API access to organization: openjournals"
    end
  end

end