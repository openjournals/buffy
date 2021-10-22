require_relative "../spec_helper.rb"

describe InitialValuesResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {values: ["target-repository"]}) }

    it "should listen to new issues" do
      expect(@responder.event_action).to eq("issues.opened")
    end

    it "should not define regex" do
      expect(@responder.event_regex).to be_nil
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {values: ["version"]})
      disable_github_calls_for(@responder)

      issue_body = "Latest Version: <!--version-->Pending<!--end-version--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    it "should do nothing if value is present" do
      expect(@responder).to_not receive(:update_issue)
      @responder.process_message("")
    end

    it "should add value to body if is not present" do
      @responder.params = { values: ["archive"] }
      expected_new_body = "**Archive:** <!--archive--><!--end-archive-->\nLatest Version: <!--version-->Pending<!--end-version--> ..."
      expect(@responder).to receive(:update_issue).with(body: expected_new_body)
      @responder.process_message("")
    end
  end

  describe "configurations" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {values: ["version"]})
      disable_github_calls_for(@responder)

      issue_body = "Version: <!--version--><!--end-version--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    it "should allow custom heading" do
      @responder.params = { values: [{author: [{heading: "Author username:"}]}] }
      expected_new_body = "Author username: <!--author--><!--end-author-->\nVersion: <!--version--><!--end-version--> ..."
      expect(@responder).to receive(:update_issue).with(body: expected_new_body)
      @responder.process_message("")
    end

    it "should allow custom value" do
      @responder.params = { values: [{author: [{value: "USERNAME"}]}] }
      expected_new_body = "**Author:** <!--author-->USERNAME<!--end-author-->\nVersion: <!--version--><!--end-version--> ..."
      expect(@responder).to receive(:update_issue).with(body: expected_new_body)
      @responder.process_message("")
    end

    it "should allow appending" do
      @responder.params = { values: [{author: [{action: "append"}]}] }
      expected_new_body = "Version: <!--version--><!--end-version--> ...\n**Author:** <!--author--><!--end-author-->"
      expect(@responder).to receive(:update_issue).with(body: expected_new_body)
      @responder.process_message("")
    end

    it "should allow full customization" do
      @responder.params = { values: [{author: [{heading: "Author username:", value: "USERNAME", action: "append"}]}] }
      expected_new_body = "Version: <!--version--><!--end-version--> ...\nAuthor username: <!--author-->USERNAME<!--end-author-->"
      expect(@responder).to receive(:update_issue).with(body: expected_new_body)
      @responder.process_message("")
    end

    it "should allow individual customizations" do
      @responder.params = { values: [{author: [{heading: "", value: "USERNAME", action: "append"}]}, {archive: nil}] }
      expected_new_body = "**Archive:** <!--archive--><!--end-archive-->\n" +
                          "Version: <!--version--><!--end-version--> ..." +
                          "\n<!--author-->USERNAME<!--end-author-->"
      expect(@responder).to receive(:update_issue).with(body: expected_new_body)
      @responder.process_message("")
    end

    it "should allow warning for empty values" do
      @responder.params = { values: [{ version: [{warn_if_empty: true}] }] }
      expect(@responder).to_not receive(:update_issue)
      expect(@responder).to receive(:respond).with("Missing values: version")
      @responder.process_message("")
    end

    it "should allow warning for non-present values" do
      @responder.params = { values: [{archive: [{warn_if_empty: true}]}] }
      expect(@responder).to receive(:update_issue)
      expect(@responder).to receive(:respond).with("Missing values: archive")
      @responder.process_message("")
    end

    it "should allow multiple warnings" do
      @responder.params = { values: [{archive: [{warn_if_empty: true}]}, {version: [{warn_if_empty: true}]}] }
      expect(@responder).to receive(:update_issue)
      expect(@responder).to receive(:respond).with("Missing values: archive, version")
      @responder.process_message("")
    end
  end

  describe "misconfiguration" do
    it "should raise error if name is missing from config" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      }.to raise_error "Configuration Error in InitialValuesResponder: No value for values."
    end

    it "should raise error if name is empty" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, { values: [] })
      }.to raise_error "Configuration Error in InitialValuesResponder: No value for values."
    end
  end
end
