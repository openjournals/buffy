require_relative "../../spec_helper.rb"

describe Openjournals::SetArchiveResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci set 10.5281/zenodo.6861996 as archive")
      expect(@responder.event_regex).to match("@botsci set 10.5281/zenodo.6861996 as archive.")
      expect(@responder.event_regex).to match("@botsci set 10.5281/zenodo.6861996 as archive   \r\n")
      expect(@responder.event_regex).to match("@botsci set 10.5281/zenodo.6861996 as archive   \r\n more")
      expect(@responder.event_regex).to_not match("@botsci set 10.5281/zenodo.6861996 as editor")
      expect(@responder.event_regex).to_not match("@botsci set 10.5281/zenodo.6861996 as archive now")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      disable_github_calls_for(@responder)

      issue_body = "...Archive: <!--archive-->Pending<!--end-archive--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    describe "with a valid DOI" do
      before do
        @msg = "@botsci set 10.5281/zenodo.6861996 as archive"
        @responder.match_data = @responder.event_regex.match(@msg)
        expect(Faraday).to receive(:head).with("https://doi.org/10.5281/zenodo.6861996").and_return(double(status: 301))
      end

      it "should update value in the body of the issue" do
        expected_new_body = "...Archive: <!--archive-->10.5281/zenodo.6861996<!--end-archive--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        @responder.process_message(@msg)
      end

      it "should respond to github" do
        expect(@responder).to receive(:respond).with("Done! archive is now [10.5281/zenodo.6861996](https://doi.org/10.5281/zenodo.6861996)")
        @responder.process_message(@msg)
      end
    end

    describe "with invalid DOI values" do
      it "should clean doi.org URLs" do
        @msg = "@botsci set https://doi.org/10.5281/zenodo.6861996 as archive"
        @responder.match_data = @responder.event_regex.match(@msg)
        expect(Faraday).to receive(:head).with("https://doi.org/10.5281/zenodo.6861996").and_return(double(status: 301))

        expected_new_body = "...Archive: <!--archive-->10.5281/zenodo.6861996<!--end-archive--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        expect(@responder).to receive(:respond).with("Done! archive is now [10.5281/zenodo.6861996](https://doi.org/10.5281/zenodo.6861996)")

        @responder.process_message(@msg)
      end

      it "should reply error if DOI doesn't resolve" do
        @msg = "@botsci set https://zenodo.org/invalid.6573452618CX as archive"
        @responder.match_data = @responder.event_regex.match(@msg)

        expect(Faraday).to receive(:head).with("https://zenodo.org/invalid.6573452618CX").and_return(double(status: 404))
        expect(@responder).to_not receive(:update_issue)
        expect(@responder).to receive(:respond).with("That doesn't look like a valid DOI value")

        @responder.process_message(@msg)
      end

      it "should reply error if malformed URI" do
        @msg = "@botsci set ' OR 1=1 as archive"
        @responder.match_data = @responder.event_regex.match(@msg)

        expect(Faraday).to_not receive(:head)
        expect(@responder).to_not receive(:update_issue)
        expect(@responder).to receive(:respond).with("That doesn't look like a valid DOI value")

        @responder.process_message(@msg)
      end
    end
  end

end
