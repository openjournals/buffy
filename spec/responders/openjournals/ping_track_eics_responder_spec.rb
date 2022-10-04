require_relative "../../spec_helper.rb"

describe Openjournals::PingTrackEicsResponder do

  subject do
    described_class
  end

  before do
    settings = { env: {bot_github_user: "editorialbot"} }
    @responder = subject.new(settings, {})
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@editorialbot ping track eic")
      expect(@responder.event_regex).to match("@editorialbot ping track eics")
      expect(@responder.event_regex).to match("@editorialbot ping track-eic")
      expect(@responder.event_regex).to match("@editorialbot ping track-eics")
      expect(@responder.event_regex).to match("@editorialbot ping track-eic.  \r\n blah blah")
      expect(@responder.event_regex).to_not match("@editorialbot ping track")
      expect(@responder.event_regex).to_not match("@editorialbot ping track-eic another command")
    end
  end

  describe "#process_message" do
    before do
      @responder.context = OpenStruct.new({ issue_id: 33 })
      disable_github_calls_for(@responder)
      @cmd = "@editorialbot ping track eic"

      @ok = double(status: 200, body: {parameterized: "testtrack"}.to_json)
      @nok = double(status: 404, body: {}.to_json)
    end

    it "should call track API point" do
      expected_url = "https://joss.theoj.org/papers/33/lookup_track"
      expect(Faraday).to receive(:get).with(expected_url).and_return(@ok)
      @responder.process_message(@cmd)
    end

    it "should allow customized journal" do
      @responder.params[:journal_base_url] = "https://another-journal.theoj.org"
      expected_url = "https://another-journal.theoj.org/papers/33/lookup_track"
      expect(Faraday).to receive(:get).with(expected_url).and_return(@ok)
      @responder.process_message(@cmd)
    end

    it "should respond pinging the track eics team" do
      expect(Faraday).to receive(:get).and_return(@ok)
      expected_response_msg = ":bellhop_bell::exclamation:Hey @openjournals/testtrack-eics, this submission requires your attention."
      expect(@responder).to receive(:respond).with(expected_response_msg)
      @responder.process_message(@cmd)
    end

    it "should respond pinging the default eics team if track can't be found" do
      expect(Faraday).to receive(:get).and_return(@nok)
      expected_response_msg = ":bellhop_bell::exclamation:Hey @openjournals/joss-eics, this submission requires your attention."
      expect(@responder).to receive(:respond).with(expected_response_msg)
      @responder.process_message(@cmd)
    end

    it "default eics team should be configurable via params" do
      @responder.params[:default_eics_team] = "@myorg/myjournal-top-editors"
      expect(Faraday).to receive(:get).and_return(@nok)
      expected_response_msg = ":bellhop_bell::exclamation:Hey @myorg/myjournal-top-editors, this submission requires your attention."
      expect(@responder).to receive(:respond).with(expected_response_msg)
      @responder.process_message(@cmd)
    end

    it "the eics teams suffix should be configurable via params" do
      @responder.params[:eics_teams_suffix] = "-chief-editors"
      expect(Faraday).to receive(:get).and_return(@ok)
      expected_response_msg = ":bellhop_bell::exclamation:Hey @openjournals/testtrack-chief-editors, this submission requires your attention."
      expect(@responder).to receive(:respond).with(expected_response_msg)
      @responder.process_message(@cmd)
    end
  end
end
