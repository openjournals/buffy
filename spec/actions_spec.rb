require_relative "./spec_helper.rb"

describe "Actions" do

  subject do
    Responder.new({}, {})
  end

  before do
    disable_github_calls_for(subject)
  end

  describe "#respond" do
    it "should call bg_respond" do
      expect(subject).to receive(:bg_respond).once.with("New message")
      subject.respond("New message")
    end
  end

  describe "#update_body" do
    it "should call update_issue on new body" do
      issue = OpenStruct.new({ body: "... <before> Here! <after> ..." })
      allow(subject).to receive(:issue).and_return(issue)

      expected_new_body = "... <before> New content! <after> ..."

      expect(subject).to receive(:update_issue).once.with({body: expected_new_body})
      subject.update_body("<before>", "<after>" ," New content! ")
    end
  end

  describe "#read_from_body" do
    it "should return stripped text between marks" do
      issue = OpenStruct.new({ body: "... <before> Here! <after> ..." })
      allow(subject).to receive(:issue).and_return(issue)

      expected_text = "Here!"

      expect(subject.read_from_body("<before>", "<after>")).to eq expected_text
    end

    it "should return empty string if nothing matches" do
      issue = OpenStruct.new({ body: "... <before> Here! <after> ..." })
      allow(subject).to receive(:issue).and_return(issue)

      expected_text = ""

      expect(subject.read_from_body("<Hey>", "<after>")).to eq expected_text
    end
  end

  describe "#replace_assignee" do
    before { disable_github_calls_for(subject) }

    it "should replace assignees if old_assignee & new_assignee are present" do
      expect(subject).to receive(:add_assignee).once.with("@new_editor")
      expect(subject).to receive(:remove_assignee).once.with("@old_editor")
      subject.replace_assignee("@old_editor", "@new_editor")
    end

    it "should not add assignee if new_assignee is blank" do
      expect(subject).to_not receive(:add_assignee)
      expect(subject).to receive(:remove_assignee).twice.with("@old_editor")
      subject.replace_assignee("@old_editor", nil)
      subject.replace_assignee("@old_editor", "")
    end

    it "should not remove assignee if old_assignee is blank" do
      expect(subject).to receive(:add_assignee).twice.with("@new_editor")
      expect(subject).to_not receive(:remove_assignee)
      subject.replace_assignee(nil, "@new_editor")
      subject.replace_assignee("", "@new_editor")
    end
  end

  describe "#invite_user" do
    before do
      allow(subject).to receive(:invitations_url).and_return("../invitations")
    end

    it "should reply if user has a pending invitation" do
      allow(subject).to receive(:is_invited?).and_return(true)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expected_response = "The reviewer already has a pending invitation.\n\n@buffy please accept the invite here: ../invitations"

      expect(subject).to_not receive(:add_collaborator)
      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end

    it "should reply if user is already a collaborator" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(true)
      expected_response = "@buffy already has access."

      expect(subject).to_not receive(:add_collaborator)
      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end

    it "should add user as collaborator otherwise" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expect(subject).to receive(:add_collaborator).and_return(true)
      expected_response = "OK, invitation sent!\n\n@buffy please accept the invite here: ../invitations"

      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end

    it "should report when unable to add user as collaborator" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expect(subject).to receive(:add_collaborator).and_return(false)
      expected_response = "It was not possible to invite @buffy"

      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end
  end
end
