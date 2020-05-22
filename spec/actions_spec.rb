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

  describe "#invite_user" do
    before do
      allow(subject).to receive(:invitations_url).and_return("../invitations")
    end

    it "should reply if user has a pending invitation" do
      allow(subject).to receive(:is_invited?).and_return(true)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expected_response = "The reviewer already has a pending invitation.\n\n@buffy please accept the invite here: ../invitations"

      expect(subject).to_not receive(:add_collaborator)
      expect(subject.invite_user("buffy")).to eq(expected_response)
    end

    it "should reply if user is already a collaborator" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(true)
      expected_response = "@buffy already has access."

      expect(subject).to_not receive(:add_collaborator)
      expect(subject.invite_user("buffy")).to eq(expected_response)
    end

    it "should add user as collaborator otherwise" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expected_response = "OK, invitation sent!\n\n@buffy please accept the invite here: ../invitations"

      expect(subject).to receive(:add_collaborator).and_return(true)
      expect(subject.invite_user("buffy")).to eq(expected_response)
    end
  end
end
