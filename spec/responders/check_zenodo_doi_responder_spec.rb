require_relative "../spec_helper.rb"

describe CheckZenodoDoiResponder do

  before do
    settings = { env: { bot_github_user: "botsci" } }
    @responder = CheckZenodoDoiResponder.new(settings, {})
    @responder.context = OpenStruct.new(issue_body: "Test Review\n\n ... description ...")
    disable_github_calls_for(@responder)
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci check zenodo doi 10.5281/zenodo.123")
      expect(@responder.event_regex).to match("@botsci check Zenodo DOI https://doi.org/10.5281/zenodo.123")
      expect(@responder.event_regex).to match("@botsci check zenodo doi 10.5281/zenodo.123   \r\n ignored part")
      expect(@responder.event_regex).to match("@botsci check zenodo doi")
      expect(@responder.event_regex).to_not match("@botsci check zenodo doi 10.5281/zenodo.123 and more")
      expect(@responder.event_regex).to_not match("@botsci check zenodo doiX")
      expect(@responder.event_regex).to_not match("@botsci check references")
    end

    it "should capture the DOI" do
      expect(@responder.event_regex.match("@botsci check zenodo doi 10.5281/zenodo.123\r\n")[1]).to eq("10.5281/zenodo.123")
    end
  end

  describe "#process_message" do
    let(:msg) { "@botsci check zenodo doi 10.5281/zenodo.123" }

    before { @responder.match_data = @responder.event_regex.match(msg) }

    it "should react to the comment and call ZenodoDoiWorker with the DOI" do
      expect(@responder).to receive(:react_to_comment).with("eyes")
      expect(ZenodoDoiWorker).to receive(:perform_async).with(hash_including("bot_name" => "botsci"), "10.5281/zenodo.123")
      @responder.process_message(msg)
    end

    it "should check values that aren't Zenodo DOIs, to say so" do
      @responder.match_data = @responder.event_regex.match("@botsci check zenodo doi 10.21105/joss.01234")
      expect(ZenodoDoiWorker).to receive(:perform_async).with(anything, "10.21105/joss.01234")
      @responder.process_message("@botsci check zenodo doi 10.21105/joss.01234")
    end

    it "should ask for a DOI if none was given" do
      @responder.match_data = @responder.event_regex.match("@botsci check zenodo doi")
      expect(@responder).to receive(:respond).with("Please give the Zenodo DOI to check, for example: `@botsci check zenodo doi 10.5281/zenodo.123456`")
      expect(@responder).to_not receive(:react_to_comment)
      expect(ZenodoDoiWorker).to_not receive(:perform_async)
      @responder.process_message("@botsci check zenodo doi")
    end
  end

  describe "#process_message when run by another responder" do
    before { @responder.run_by_other_responder = true }

    def run_with(msg)
      @responder.match_data = @responder.event_regex.match(msg)
      @responder.process_message(msg)
    end

    it "should check Zenodo DOIs" do
      expect(@responder).to receive(:react_to_comment).with("eyes")
      expect(ZenodoDoiWorker).to receive(:perform_async).with(anything, "10.5281/zenodo.123")
      run_with("@botsci check zenodo doi 10.5281/zenodo.123")
    end

    ["@botsci check zenodo doi 10.21105/joss.01234", "@botsci check zenodo doi", "@botsci check zenodo doi some text"].each do |msg|
      it "should say and do nothing for #{msg.inspect}" do
        expect(@responder).to_not receive(:respond)
        expect(@responder).to_not receive(:react_to_comment)
        expect(ZenodoDoiWorker).to_not receive(:perform_async)
        run_with(msg)
      end
    end
  end

  describe "documentation" do
    it "has a description and an example invocation" do
      expect(@responder.description).to eq("Check that a Zenodo DOI is a version DOI (a concept DOI fails)")
      expect(@responder.example_invocation).to eq("@botsci check zenodo doi 10.5281/zenodo.123456")
    end
  end
end
