require_relative "../spec_helper.rb"

describe SetValueResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({ bot_github_user: "botsci" }, { name: "version" }) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci set v1.0.3-beta as version")
      expect(@responder.event_regex).to match("@botsci set 2.345 as version   \r\n")
      expect(@responder.event_regex).to_not match("@botsci set v12.0 as editor")
      expect(@responder.event_regex).to_not match("@botsci set v1.0.3-beta as version now")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({ bot_github_user: "botsci" }, { name: "version" })
      disable_github_calls_for(@responder)

      @msg = "@botsci set v0.0.33-alpha as version"
      @responder.match_data = @responder.event_regex.match(@msg)

      issue_body = "...Latest Version: <!--version-->Pending<!--end-version--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    it "should update value in the body of the issue" do
      expected_new_body = "...Latest Version: <!--version-->v0.0.33-alpha<!--end-version--> ..."
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
      @responder.process_message(@msg)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("Done! version is now v0.0.33-alpha")
      @responder.process_message(@msg)
    end
  end

  describe "misconfiguration" do
    it "should raise error if name is missing from config" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, {})
      }.to raise_error "Configuration Error in SetValueResponder: No value for name."
    end

    it "should raise error if name is empty" do
      expect {
        @responder = subject.new({ bot_github_user: "botsci" }, { name: "    " })
      }.to raise_error "Configuration Error in SetValueResponder: No value for name."
    end
  end

  describe "documentation" do
    before do
      @responder = subject.new({ bot_github_user: "botsci" }, { name: "archive", sample_value: "10.21105/joss.12345"})
    end

    it "#description should include name" do
      expect(@responder.description).to eq("Set a value for archive")
    end

    it "#example_invocation should use custom sample value if present" do
      expect(@responder.example_invocation).to eq("@botsci set 10.21105/joss.12345 as archive")
    end

    it "#example_invocation should have default sample value" do
      @responder.params = { name: "archive" }
      expect(@responder.example_invocation).to eq("@botsci set xxxxx as archive")
    end
  end
end
