require_relative "./spec_helper.rb"

describe ResponderRegistry do

  before do
    @config = Sinatra::IndifferentHash[responders: { "hello" => { hidden: true },
                              "assign_editor" => { only: "editors" },
                              "set_value" => [
                                { version: { only: "editors" }},
                                { archival: { name: "archive", sample_value: "doi42" }},
                                { url: nil }
                              ]
                            }
              ]
  end

  describe "initialization" do
    it "should load available responders mapping" do
      registry = described_class.new(@config)
      expect(registry.responders_map).to eq(ResponderRegistry.available_responders)
    end

    it "should load single responders" do
      registry = described_class.new(@config)
      single_responder = registry.responders.select { |r| r.kind_of?(AssignEditorResponder) }

      expect(single_responder.size).to eq(1)
      expect(single_responder[0].params).to eq("only" => "editors")
      expect(single_responder[0].params[:only]).to eq("editors")
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
      @config[:env] = { gh_access_token: "ABC123" }
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.with("openjournals").and_return([{name: "eics", id: 42}])
      expected_teams = { editors: 11, eics: 42 }

      registry = described_class.new(@config)
      responders = registry.responders

      expect(responders.size).to eq(5)
      responders.each do |responder|
        expect(responder.teams[:editors]).to eq(expected_teams[:editors])
        expect(responder.teams[:eics]).to eq(expected_teams[:eics])
      end
    end
  end

  describe ".available_responders" do
    it "should return a map of all available responders" do
      map = ResponderRegistry.available_responders
      files_count = Dir["#{File.expand_path '../../app/responders', __FILE__}/**/*.rb"].length
      expect(map.count).to eq(files_count)

      random_responder_key = map.keys[(0..files_count-1).to_a.sample]
      expect(map[random_responder_key].key).to eq(random_responder_key)
    end
  end

  describe ".get_responder" do
    it "should return a responder by key" do
      responder = ResponderRegistry.get_responder(@config, "assign_editor")
      expect(responder).to_not be_nil
      expect(responder).to be_a(AssignEditorResponder)
      expect(responder.params).to eq({ "only" => "editors" })
    end

    it "should return an instance by name" do
      responder = ResponderRegistry.get_responder(@config, "set_value", "archival")
      expect(responder).to_not be_nil
      expect(responder).to be_a(SetValueResponder)
      expect(responder.params).to eq({ "name" => "archive", "sample_value" => "doi42" })
    end

    it "should return nil if no instance matching key+name" do
      expect(ResponderRegistry.get_responder(@config, "set_value")).to be_nil
      expect(ResponderRegistry.get_responder(@config, "set_value", "branch")).to be_nil
      expect(ResponderRegistry.get_responder(@config, "assign_editor", "topic")).to be_nil
    end

    it "should return nil if no key or config" do
      expect(ResponderRegistry.get_responder({}, :set_value)).to be_nil
      expect(ResponderRegistry.get_responder(@config, nil)).to be_nil
    end
  end
end
