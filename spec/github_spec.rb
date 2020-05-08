require_relative "./spec_helper.rb"

describe "Github methods" do

  subject do
    settings = Sinatra::IndifferentHash[teams: { editors: 11, reviewers: 22, eics: 33 }]
    params ={ only: ['editors', 'eics'] }
    Responder.new(settings, params)
  end

  before do
    @context = OpenStruct.new({ repo: 'openjournals/buffy', issue_id: 5})
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
      expect_any_instance_of(Octokit::Client).to receive(:issue).once.with('openjournals/buffy', 5).and_return("issue")
      subject.issue(@context)
      subject.issue(@context)
    end
  end

  describe "#bg_respond" do
    it "should add comment to github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:add_comment).once.with('openjournals/buffy', 5, 'comment!')
      subject.bg_respond("comment!", @context)
    end
  end

  describe "#label_issue" do
    it "should add labels to github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:add_labels_to_an_issue).once.with('openjournals/buffy', 5, ['reviewed'])
      subject.label_issue(['reviewed'], @context)
    end
  end

  describe "#update_issue" do
    it "should add labels to github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:update_issue).once.with('openjournals/buffy', 5, { body: "new body"})
      subject.update_issue(@context, body: "new body")
    end
  end

  describe "#authorized_people" do
    it "should return all people in authorized teams" do
      editors_team = [OpenStruct.new(login: "supereditor")]
      eics_team = [OpenStruct.new(login: "supereditor")]
      [1,2].each do |n|
        editors_team << OpenStruct.new(login: "editor_#{n}")
        eics_team << OpenStruct.new(login: "eic_#{n}")
      end
      expect_any_instance_of(Octokit::Client).to receive(:team_members).once.with(11).and_return(editors_team)
      expect_any_instance_of(Octokit::Client).to receive(:team_members).once.with(33).and_return(eics_team)

      expect(subject.authorized_people).to eq(["editor_1", "editor_2", "eic_1", "eic_2", "supereditor"])
    end
  end

  describe "#authorized_people" do
    it "should return true if user is member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(true)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(33, "sender")

      expect(subject.user_authorized?("sender")).to be_truthy
    end
  end

  describe "#authorized_people" do
    it "should return false if user is not member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(false)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(33, "sender").and_return(false)

      expect(subject.user_authorized?("sender")).to be_falsey
    end
  end

end