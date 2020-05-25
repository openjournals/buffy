require_relative "./spec_helper.rb"

describe ResponderRegistry do

  before do
    @config = { responders: { "hello" => { hidden: true },
                              "assign_reviewer_n" => { only: "editors" },
                              "set_value" => [
                                { version: { only: "editors" }},
                                { archival: { name: "archive", sample_value: "doi42" }},
                                { url: nil }
                              ]
                            }
              }
  end

  describe "initialization" do
    it "should load single responders" do
      registry = described_class.new(@config)
      single_responder = registry.responders.select { |r| r.kind_of?(AssignReviewerNResponder) }

      expect(single_responder.size).to eq(1)
      expect(single_responder[0].params).to eq({ only: "editors" })
    end

    it "should load multiple instances of the same responder" do
      registry = described_class.new(@config)
      responders = registry.responders.select { |r| r.kind_of?(SetValueResponder) }

      expect(responders.size).to eq(3)

      version = responders[0]
      archival = responders[1]
      url = responders[2]

      expect(version.params[:name]).to eq("version")
      expect(version.params[:only]).to eq("editors")
      expect(archival.params[:name]).to eq("archive")
      expect(archival.params[:only]).to be_nil
      expect(archival.params[:sample_value]).to eq("doi42")
      expect(url.params[:name]).to eq("url")
      expect(url.params[:only]).to be_nil
      expect(url.params[:sample_value]).to be_nil
    end
  end

  describe "loading responders" do
    it "should retrieve all teams ids once" do
      @config[:teams] = { editors: 11, eics: "openjournals/eics" }
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.with("openjournals").and_return([{name: "eics", id: 42}])
      expected_teams = { editors: 11, eics: 42 }

      registry = described_class.new(@config)
      responders = registry.responders

      expect(responders.size).to eq(5)
      responders.each do |responder|
        expect(responder.teams).to eq(expected_teams)
      end
    end
  end

end
