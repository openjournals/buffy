require_relative "./spec_helper.rb"

describe "Github methods" do

  subject do
    settings = Sinatra::IndifferentHash[env: {}, teams: { editors: 11, reviewers: 22, eics: 33 }]
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

  describe "#issue_body" do
    it "should get body from context if present" do
      subject.context.issue_body = "Body Issue in Context"

      expect(subject).to_not receive(:issue)
      expect(subject.issue_body).to eq("Body Issue in Context")
    end

    it "should get body calling #issue if not available in context" do
      subject.context.issue_body = nil

      expect(subject).to receive(:issue).once.and_return(OpenStruct.new(body: "Body from calling issue"))
      expect(subject.issue_body).to eq("Body from calling issue")
    end
  end

  describe "#template_url" do
    it "should get the download url of a template" do
      expected_url = "https://github.com/openjournals/buffy/templates/test_message.md"
      expect_any_instance_of(Octokit::Client).to receive(:contents).once.and_return(OpenStruct.new(download_url: expected_url))

      expect(subject.template_url("test_message.md")).to eq(expected_url)
    end

    it "should get the contents for the right template file" do
      expected_path = Pathname.new "#{subject.default_settings[:templates_path]}/test_message.md"
      response = OpenStruct.new(download_url: "")
      expect_any_instance_of(Octokit::Client).to receive(:contents).once.with("openjournals/buffy", path: expected_path).and_return(response)

      subject.template_url("test_message.md")
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

  describe "#unlabel_issue" do
    it "should remove label from github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_label).once.with("openjournals/buffy", 5, "pending-review")
      subject.unlabel_issue("pending-review")
    end
  end

  describe "#issue_labels" do
    it "should return the labels names from github issue" do
      labels = [{id:1, name: "A"}, {id:21, name: "J"}]
      expect_any_instance_of(Octokit::Client).to receive(:labels_for_issue).once.with("openjournals/buffy", 5).and_return(labels)
      expect(subject.issue_labels).to eq(["A", "J"])
    end
  end

  describe "#update_issue" do
    it "should update github issue with received options" do
      expect_any_instance_of(Octokit::Client).to receive(:update_issue).once.with("openjournals/buffy", 5, { body: "new body"})
      subject.update_issue({body: "new body"})
    end
  end

  describe "#close_issue" do
    it "should close a github issue with received options" do
      expect_any_instance_of(Octokit::Client).to receive(:close_issue).once.with("openjournals/buffy", 5, { labels: "rejected" })
      subject.close_issue({ labels: "rejected" })
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

  describe "#add_assignee" do
    it "should add the user to the repo's assignees list" do
      expect_any_instance_of(Octokit::Client).to receive(:add_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.add_assignee("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:add_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.add_assignee("@XuanXu")
    end
  end

  describe "#remove_assignee" do
    it "should remove the user from the repo's assignees list" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.remove_assignee("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.remove_assignee("@XuanXu")
    end
  end

  describe "#can_be_assignee?" do
    it "should check if user can be an assignee of the repo" do
      expect_any_instance_of(Octokit::Client).to receive(:check_assignee).once.with("openjournals/buffy", "buffy")
      subject.can_be_assignee?("buffy")
    end
  end

  describe "#add_new_team" do
    context "with valid permissions" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_team).
                                                  with("openjournals", {name: "superusers"}).
                                                  and_return({status: "201"})
      end

      it "should create the team and return true" do
        expect(subject.add_new_team("openjournals/superusers")).to be_truthy
      end
    end

    context "with invalid permissions" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_team).and_raise(Octokit::Forbidden)
        allow(subject.logger).to receive(:warn)
      end

      it "should return false" do
        expect(subject.add_new_team("openjournals/superusers")).to be_falsy
      end

      it "should log a warning" do
        expect(subject.logger).to receive(:warn).with("Error trying to create team openjournals/superusers: Octokit::Forbidden")
        subject.add_new_team("openjournals/superusers")
      end
    end
  end

  describe "#invite_user_to_team" do
    it "should be false if user can't be found" do
      expect(Octokit).to receive(:user).with("nouser").and_raise(Octokit::NotFound)
      expect(subject.invite_user_to_team("nouser", "my-teams")).to be_falsy
    end

    it "should be false if team does not exist" do
      expect(Octokit).to receive(:user).with("user42").and_return(double(id: 33))
      expect(subject).to receive(:team_id).and_return(nil)
      expect(subject).to receive(:add_new_team).and_return(nil)

      expect(subject.invite_user_to_team("@user42", "openjournals/superusers")).to be_falsy
    end

    it "should be false if can't create team" do
      expect(Octokit).to receive(:user).and_return(double(id: 33))
      expect(subject).to receive(:team_id).and_return(nil)
      allow_any_instance_of(Octokit::Client).to receive(:create_team).and_return(false)

      expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_falsy
    end

    it "should try to create team if it does not exist" do
      expect(Octokit).to receive(:user).and_return(double(id: 33))
      expect(subject).to receive(:team_id).and_return(nil)
      expect(subject).to receive(:add_new_team).with("openjournals/superusers").and_return(double(id: 3333))
      expect(Faraday).to receive(:post).and_return(double(status: 200))

      subject.invite_user_to_team("user42", "openjournals/superusers")
    end

    it "should be false if invitation can not be created" do
      expect(Octokit).to receive(:user).and_return(double(id: 33))
      expect(subject).to receive(:team_id).with("openjournals/superusers").and_return(1234)
      expect(Faraday).to receive(:post).and_return(double(status: 403))

      expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_falsy
    end

    it "should be true when invitation is created" do
      expect(Octokit).to receive(:user).and_return(double(id: 33))
      expect(subject).to receive(:team_id).with("openjournals/superusers").and_return(1234)
      expect(Faraday).to receive(:post).and_return(double(status: 201))

      expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_truthy
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

  describe "#user_in_authorized_teams?" do
    it "should return true if user is member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(true)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(33, "sender")

      expect(subject.user_in_authorized_teams?("sender")).to be_truthy
    end

    it "should return false if user is not member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(false)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(33, "sender").and_return(false)

      expect(subject.user_in_authorized_teams?("sender")).to be_falsey
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

  describe "#user_login" do
    it "should remove the @ from a username" do
      expect(subject.user_login("@buffy")).to eq("buffy")
    end

    it "should downcase the username" do
      expect(subject.user_login("@BuFFy")).to eq("buffy")
    end

    it "should strip the username" do
      expect(subject.user_login(" Buffy  ")).to eq("buffy")
    end
  end

  describe "#username?" do
    it "should be true if username starts with @" do
      expect(subject.username?("@buffy")).to be_truthy
    end

    it "should be false otherwise" do
      expect(subject.username?("buffy")).to be_falsey
    end
  end

end