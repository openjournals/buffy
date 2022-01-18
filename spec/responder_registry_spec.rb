require_relative "./spec_helper.rb"

describe ResponderRegistry do

  before do
    @config = Sinatra::IndifferentHash[env: { bot_github_user: "botsci" },
                                        responders: { "hello" => { hidden: true },
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

  describe "#accept_message?" do
    it "should be true if any responder responds to the message" do
      registry = described_class.new(@config)
      expect(registry.accept_message?("Hello @botsci")).to be true
      expect(registry.accept_message?("@botsci assign me as editor")).to be true
      expect(registry.accept_message?("@botsci set v1.0 as version")).to be true
      expect(registry.accept_message?("@botsci set dois212 as archive")).to be true
      expect(registry.accept_message?("@botsci set www as url")).to be true
    end

    it "should be false if no responder responds to the message" do
      registry = described_class.new(@config)
      expect(registry.accept_message?("@botsci whatever")).to be false
      expect(registry.accept_message?("Hello @bot")).to be false
      expect(registry.accept_message?("@botsci set v1.0 as unknown_param")).to be false
    end
  end

  describe "#reply_for_wrong_command" do
    it "should call WrongCommandResponder with proper info" do
      context = OpenStruct.new(issue_id: 15, issue_author: "opener", event_action: "issue_comment.created")
      message = "@botsci whatever"

      expected_context = OpenStruct.new(issue_id: 15, issue_author: "opener", event_action: "wrong_command")
      expect(WrongCommandResponder).to receive(:new).with(@config, {}).and_return(WrongCommandResponder.new(@config, {}))
      expect_any_instance_of(WrongCommandResponder).to receive(:call).with(message, expected_context)

      registry = described_class.new(@config)
      registry.reply_for_wrong_command(message, context)
    end

    it "should use params from wrong_command config" do
      message = "@botsci whatever"
      context = OpenStruct.new(event_action: "issue_comment.created")
      expected_context = OpenStruct.new(event_action: "wrong_command")
      params =  {ignore: true, message: "I don't understand"}
      config = @config.merge(responders: {wrong_command: params})
      registry = described_class.new(config)

      expect(WrongCommandResponder).to receive(:new).with(config, params).and_return(WrongCommandResponder.new(config, params))
      expect_any_instance_of(WrongCommandResponder).to receive(:call).with(message, expected_context)

      registry.reply_for_wrong_command(message, context)
    end
  end

  describe "#respond" do
    it "should call responders" do
      msg = "Hi @botsci"
      context = OpenStruct.new(event_action: "issue_comment.created")

      registry = described_class.new(@config)
      registry.responders.each do |responder|
        expect(responder).to receive(:call).with(msg, context)
      end

      registry.respond(msg, context)
    end

    it "should call reply_for_wrong_command if no responder understand the message" do
      registry = described_class.new(@config)
      expect(registry).to receive(:reply_for_wrong_command)

      registry.respond("@botsci whatever", OpenStruct.new(event_action: "issue_comment.created"))
    end

    it "should not call reply_for_wrong_command if any responder understand the message" do
      registry = described_class.new(@config)
      expect(registry).to_not receive(:reply_for_wrong_command)
      expect_any_instance_of(HelloResponder).to receive(:call)

      registry.respond("Hi @botsci", OpenStruct.new(event_action: "issue_comment.created"))
    end
  end

end
