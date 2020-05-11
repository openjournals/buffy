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

end
