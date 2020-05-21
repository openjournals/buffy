require_relative "./spec_helper.rb"

describe ResponderRegistry do

  before do
    @config = { responders: { "hello" => { hidden: true },
                              "assign_reviewer_n" => { only: "editors" },
                              "set_value" => [
                                { version: { only: "editors" }},
                                { archival: { name: "archive", sample_value: "doi42" }}
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

      expect(responders.size).to eq(2)

      version = responders[0]
      archival = responders[1]

      expect(version.params[:name]).to eq("version")
      expect(version.params[:only]).to eq("editors")
      expect(archival.params[:name]).to eq("archive")
      expect(archival.params[:only]).to be_nil
      expect(archival.params[:sample_value]).to eq("doi42")
    end
  end

end
