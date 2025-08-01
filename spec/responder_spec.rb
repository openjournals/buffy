require_relative "./spec_helper.rb"

describe Responder do

  subject do
    described_class.new({}, {})
  end

  before do
    subject.event_action = "test_created"
    subject.event_regex = /\Atesting\z/
  end

  describe "#responds_on?" do
    it "should be true if there is not event_action defined" do
      subject.event_action = nil
      expect(subject.responds_on?(OpenStruct.new({ event_action: "whatever" }))).to be_truthy
    end

    it "should be true for the defined event_action" do
      expect(subject.responds_on?(OpenStruct.new({ event_action: "test_created" }))).to be_truthy
    end

    it "should be false for other event_actions" do
      expect(subject.responds_on?(OpenStruct.new({ event_action: "test_edited" }))).to be_falsey
      expect(subject.responds_on?(OpenStruct.new({ event_action: "" }))).to be_falsey
      expect(subject.responds_on?(OpenStruct.new({ event_action: nil }))).to be_falsey
    end
  end

  describe "#responds_to?" do
    it "should be true if there is not event_regex defined" do
      subject.event_regex = nil
      expect(subject.responds_to?("whatever")).to be_truthy
    end

    it "should be true if message matches the event_regex" do
      expect(subject.responds_to?("testing")).to be_truthy
    end

    it "should be false when messages don't match the event_regex" do
      expect(subject.responds_to?("test")).to be_falsey
      expect(subject.responds_to?("testing again")).to be_falsey
      expect(subject.responds_to?("" )).to be_falsey
      expect(subject.responds_to?(nil )).to be_falsey
    end
  end

  describe "#authorized?" do
    before do
      @context = OpenStruct.new({ sender: "sender" })
    end

    it "should be true if there is not restrictions (nil :only/:authorized_roles_in_issue settings)" do
      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be true if sender is in an authorized team" do
      subject.params = { only: 'editors' }
      allow(subject).to receive(:user_authorized?).with("sender").and_return(true)
      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be true if sender is listed in an authorized role in the issue" do
      subject.params = { authorized_roles_in_issue: 'reviewers' }
      @context[:issue_body] = "<!--reviewers-->@rev1, @sender<!--end-reviewers-->"
      subject.context = @context

      expect(subject).to_not receive(:user_authorized?)
      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be true if sender is not in an authorized role but is in authorized team" do
      @context[:issue_body] = "<!--reviewers-->@rev1, @rev2<!--end-reviewers-->"
      subject.params = { only: 'editors', authorized_roles_in_issue: 'reviewers'}
      subject.context = @context
      allow(subject).to receive(:user_authorized?).with("sender").and_return(true)

      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be true if sender is not in an authorized team but is in authorized role" do
      @context[:issue_body] = "<!--reviewers-->@rev1, @sender<!--end-reviewers-->"
      subject.params = { only: 'editors', authorized_roles_in_issue: 'reviewers'}
      subject.context = @context
      allow(subject).to receive(:user_authorized?).with("sender").and_return(false)

      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be true if sender is in an authorized team and in authorized role" do
      @context[:issue_body] = "<!--reviewers-->@rev1, @sender<!--end-reviewers-->"
      subject.params = { only: 'editors', authorized_roles_in_issue: 'reviewers'}
      subject.context = @context
      allow(subject).to receive(:user_authorized?).with("sender").and_return(true)

      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be false if sender is not in any authorized team" do
      subject.params = { only: 'editors' }
      allow(subject).to receive(:user_authorized?).with("sender").and_return(false)
      expect(subject.authorized?(@context)).to be_falsey
    end

    it "should be false if sender is not in any authorized role" do
      @context[:issue_body] = "<!--author-->AuthorName<!--end-author--><!--reviewers-->@rev1, @rev2<!--end-reviewers-->"
      subject.params = { authorized_roles_in_issue: ['reviewers', 'author']}
      subject.context = @context
      expect(subject).to_not receive(:user_authorized?)
      expect(subject.authorized?(@context)).to be_falsey
    end

    it "should be false if sender is not in any authorized team or role" do
      @context[:issue_body] = "<!--reviewers-->@rev1, @rev2<!--end-reviewers-->"
      subject.params = { only: 'editors', authorized_roles_in_issue: 'reviewers'}
      subject.context = @context
      allow(subject).to receive(:user_authorized?).with("sender").and_return(false)
      expect(subject.authorized?(@context)).to be_falsey
    end
  end

  describe "#meet_conditions?" do
    before do
      @responder = Responder.new({}, {})
      @responder.context = OpenStruct.new(issue_title: "[REVIEW] Software review",
                                          issue_labels: [OpenStruct.new(id: 1, name: "accepted"),
                                                         OpenStruct.new(id: 2, name: "python")],
                                          issue_body: "Test Review\n\n ... description ...\n" +
                                                      "<!--editor-->@editor<!--end-editor-->\n" +
                                                      "<!--editor-2-->L.B.<!--end-editor-2-->\n" +
                                                      "<!--author--><!--end-author-->\n"+
                                                      "<!--submission_type-->astro<!--end-submission_type-->\n")
      disable_github_calls_for(@responder)
    end

    it "should be true if there is not conditions (via :if setting)" do
      @responder.params = {}
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {}}
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {title: nil, body: nil, value_exists: nil}}
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {title: "", body: "", value_exists: ""}}
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be false if title condition is not met" do
      @responder.params = { if: {title: "PRE-REVIEW"} }
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if body condition is not met" do
      @responder.params = { if: {body: "ABCDEFG"} }
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if value_exists condition is not met" do
      @responder.params = { if: {value_exists: "author"} }
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if value_matches condition is not met" do
      @responder.params = { if: {value_matches: { submission_type: "math"} } }
      expect(@responder.meet_conditions?).to be_falsy

      @responder.params = { if: {value_matches: { submission_type: "^stro"} } }
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if any value_matches condition is not met" do
      @responder.params = { if: {value_matches: { author: "L.B.", submission_type: "astro" } } }
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should raise an error if value_matches is mksconfigured" do
      @responder.params = { if: {value_matches: "submission_type"} }
      expect{
        @responder.meet_conditions?
      }.to raise_error "Configuration Error in Responder: value_matches should be a hash of [field_name:expected_value] pairs"
    end

    it "should be false if role_assigned condition is not met" do
      @responder.params = { if: {role_assigned: "editor-2"} } #no username
      expect(@responder.meet_conditions?).to be_falsy

      @responder.params = { if: {role_assigned: "author"} } # empty
      expect(@responder.meet_conditions?).to be_falsy

      @responder.params = { if: {role_assigned: "reviewers"} } #no present
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if labels condition is not met" do
      @responder.params = { if: {labels: "whatever"} }
      expect(@responder.meet_conditions?).to be_falsy

      @responder.params = { if: {labels: ["accepted", "published"]} }
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if any condition is not met" do
      @responder.params = { if: {title: "REVIEW", body: "^Test Review", labels: "accepted", value_exists: "author", reject_msg: "Can't do that"} }
      expect(@responder).to receive(:respond).with("Can't do that")
      expect(@responder.meet_conditions?).to be_falsey
    end

    it "should not respond if there is no rejection message" do
      @responder.params = { if: {title: "New Submission"} }
      expect(@responder).to_not receive(:respond).with("Can't do that")
      expect(@responder.meet_conditions?).to be_falsey
    end

    it "should respond the rejection message if condition is not met" do
      @responder.params = { if: {title: "New Submission", reject_msg: "Wrong issue title"} }
      expect(@responder).to receive(:respond).with("Wrong issue title")
      expect(@responder.meet_conditions?).to be_falsey
    end

    it "should be true if title condition is met" do
      @responder.params = { if: {title: "^\\[REVIEW\\]"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {title: "REVIEW"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true if body condition is met" do
      @responder.params = { if: {body: "^Test Review"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {body: "description"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true if value_exists condition is met" do
      @responder.params = { if: {value_exists: "editor-2"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true if value_matches condition is met" do
      @responder.params = { if: {value_matches: { author: "", submission_type: "astro" } } }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {value_matches: { submission_type: "^as" } } }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true if role_assigned condition is met" do
      @responder.params = { if: {role_assigned: "editor"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true if labels condition is met" do
      @responder.params = { if: {labels: "accepted"} }
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {labels: "python"} }
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {labels: ["accepted", "python"]} }
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true only if all conditions are met" do
      @responder.params = { if: {title: "REVIEW",
                                 body: "^Test Review",
                                 value_exists: "editor-2",
                                 role_assigned: "editor",
                                 labels: "accepted",
                                 submission_type: "astro",
                                 reject_msg: "Error"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end
  end

  describe "#call" do
    it "should not process message if responds_on? is false" do
      allow(subject).to receive(:responds_on?).and_return(false)
      allow(subject).to receive(:responds_to?).and_return(true)
      allow(subject).to receive(:authorized?).and_return(true)
      allow(subject).to receive(:process_message).never
      expect(subject.call("testing", {})).to be false
    end

    it "should not process message if responds_to? is false" do
      allow(subject).to receive(:responds_on?).and_return(true)
      allow(subject).to receive(:responds_to?).and_return(false)
      allow(subject).to receive(:authorized?).and_return(true)
      allow(subject).to receive(:process_message).never
      expect(subject.call("testing", {})).to be false
    end


    it "should not process message if authorized? is false" do
      context = OpenStruct.new(sender: "tester", repo: "openjournals/buffy")
      subject.params = {only: ['editors', 'owners'], authorized_roles_in_issue: ["author"]}
      allow(subject).to receive(:responds_on?).and_return(true)
      allow(subject).to receive(:responds_to?).and_return(true)
      allow(subject).to receive(:authorized?).and_return(false)
      allow(subject).to receive(:respond).and_return(true)
      allow(subject).to receive(:process_message).never
      expected_msg = "I'm sorry @tester, I'm afraid I can't do that. That's something only editors, owners and author are allowed to do."
      expect(subject).to receive(:respond).once.with(expected_msg)
      expect(subject.call("testing", context)).to be true
    end

    it "should process message if responds_on?, responds_to? and authorized? are all true" do
      context = OpenStruct.new({ event_action: "test_created", repo: "openjournals/buffy" })
      message = "testing"
      allow(subject).to receive(:responds_on?).and_return(true)
      allow(subject).to receive(:responds_to?).and_return(true)
      allow(subject).to receive(:authorized?).and_return(true)
      allow(subject).to receive(:process_message).and_return(true)

      expect(subject).to receive(:process_message).once.with(message)
      expect(subject.call(message, context)).to be true
      expect(subject.context).to eq(context)
    end
  end

  describe "#locals" do
    before do
      @responder = described_class.new({ env: {bot_github_user: 'botsci'} }, {})
      @responder.context = OpenStruct.new(issue_id: 5,
                                          issue_title: "Test submission",
                                          issue_author: "opener",
                                          repo: "openjournals/buffy",
                                          sender: "user33",
                                          issue_body: "Test Software Review\n\n<!--reviewer-->@xuanxu<!--end-reviewer-->")
    end

    it "should include basic config info" do
      expected_locals = Sinatra::IndifferentHash[issue_id: 5, issue_author: "opener", issue_title: "Test submission", bot_name: "botsci", repo: "openjournals/buffy", sender: "user33"]
      expect(@responder.locals).to eq(expected_locals)
    end

    it "should add info from the issue body if requested" do
      @responder.params = {data_from_issue: ["reviewer"]}
      expected_locals = Sinatra::IndifferentHash[issue_id: 5, issue_author: "opener", issue_title: "Test submission", bot_name: "botsci", repo: "openjournals/buffy", sender: "user33", "reviewer" => "@xuanxu"]
      expect(@responder.locals).to eq(expected_locals)
    end

    it "should add info from the event_regex if present" do
      expected_locals = Sinatra::IndifferentHash[issue_id: 5, issue_author: "opener", issue_title: "Test submission", bot_name: "botsci", repo: "openjournals/buffy", sender: "user33", match_data_1: "@xuanxu"]
      @responder.event_regex = /\A@bot assign (.*) as editor\z/i
      @responder.match_data = @responder.event_regex.match("@bot assign @xuanxu as editor")

      expect(@responder.locals).to eq(expected_locals)
    end

    it "context data should not be overwritten by issue body data" do
      @responder.context["issue_body"] += "<!--issue_id-->42<!--end-issue_id--><!--x-->Y<!--end-x-->"
      @responder.params = {data_from_issue: ["x", "issue_id"]}
      expect(@responder.read_value_from_body("issue_id")).to eq("42")
      expect(@responder.locals[:x]).to eq("Y")
      expect(@responder.locals[:issue_id]).to eq(5)
    end
  end

  describe "get_data_from_issue" do
    before do
      @responder = described_class.new({ env: {bot_github_user: 'botsci'} }, {})
      @responder.context = OpenStruct.new(issue_body: "Test Software Review\n\n" +
                                                      "<!--first-->1111<!--end-first-->" +
                                                      "<!--second-->2222<!--end-second-->" +
                                                      "<!--third-->3333<!--end-third-->")
    end

    it "should be empty if no values listed" do
      expected = Sinatra::IndifferentHash.new
      expect(@responder.get_data_from_issue(nil)).to eq(expected)
    end

    it "should extract listed values from issue body" do
      expected = Sinatra::IndifferentHash[first: "1111", third: "3333"]
      expect(@responder.get_data_from_issue(["first", "third"])).to eq(expected)
    end
  end

  describe "get_data_from_command_regex" do
    before do
      @responder = described_class.new({ env: {bot_github_user: 'botsci'} }, {})
    end

    it "should be empty if no values captured in the event_regex" do
      @responder.event_regex = /\A@bot generate pdf\.?\s*\z/i
      @responder.responds_to?("@bot generate pdf")
      expected = Sinatra::IndifferentHash.new
      expect(@responder.get_data_from_command_regex).to eq(expected)
    end

    it "should extract captured values from event_regex" do
      @responder.event_regex = /\A@bot assign (.*) as (.*)\.?\s*\z/i
      @responder.responds_to?("@bot assign @astrophysics-editor as editor")
      expected = Sinatra::IndifferentHash[match_data_1: "@astrophysics-editor", match_data_2: "editor"]
      expect(@responder.get_data_from_command_regex).to eq(expected)
    end
  end

  describe "#hidden?" do
    it "should be true if params[:hidden] is true" do
      responder = described_class.new({}, { hidden: true })
      expect(responder).to be_hidden
    end

    it "should be false otherwise" do
      responder = described_class.new({}, {})
      expect(responder).to_not be_hidden

      responder = described_class.new({}, { hidden: false })
      expect(responder).to_not be_hidden

      responder = described_class.new({}, { hidden: "wrong value" })
      expect(responder).to_not be_hidden
    end
  end

  describe ".keyname" do
    it "should be class name by default" do
      expect(described_class.key).to eq("Responder")
    end

    it "should set the key name" do
      described_class.keyname :buffy_tester
      expect(described_class.key).to eq("buffy_tester")
    end
  end

  describe "#key" do
    it "should be present for all responders" do
      ResponderRegistry.available_responders.values.each do |responder_class|
        expect(responder_class.key).to_not be_nil
        expect(responder_class.key).to_not eq(responder_class.name)
      end
    end
  end

  describe "#description" do
    it "should be customizable via settings file" do
      responder = described_class.new({}, { description: "Custom description!" })
      expect(responder).to_not receive(:default_description)
      expect(responder.description).to eq("Custom description!")
    end

    it "should have default value" do
      responder = described_class.new({}, {})
      expect(responder).to receive(:default_description).and_return("Default description!")
      expect(responder.description).to eq("Default description!")
    end
  end

  describe "#example_invocation" do
    it "should be customizable via settings file" do
      responder = described_class.new({}, { example_invocation: "Custom example_invocation!" })
      expect(responder).to_not receive(:default_example_invocation)
      expect(responder.example_invocation).to eq("Custom example_invocation!")
    end

    it "should have default value" do
      responder = described_class.new({}, {})
      expect(responder).to receive(:default_example_invocation).and_return("Default example_invocation!")
      expect(responder.example_invocation).to eq("Default example_invocation!")
    end
  end

  describe "#default_description" do
    it "should be present for all responders" do
      ResponderRegistry.available_responders.values.each do |responder_class|
        responder = responder_class.new({}, sample_params(responder_class))
        expect(responder.respond_to?(:description)).to eq(true)
        expect(responder.default_description).to_not be_nil
        expect(responder.default_description).to_not be_empty
      end
    end
  end

  describe "#default_example_invocation" do
    it "should be present for all responders" do
      ResponderRegistry.available_responders.values.each do |responder_class|
        responder = responder_class.new({}, sample_params(responder_class))
        expect(responder.respond_to?(:example_invocation)).to eq(true)
        expect(responder.default_example_invocation).to_not be_nil
        expect(responder.default_example_invocation).to_not be_empty
      end
    end
  end

  describe "multiple descriptions and example invocations" do
    it "should have the same number of each of them" do
      ResponderRegistry.available_responders.values.each do |responder_class|
        responder = responder_class.new({}, sample_params(responder_class))
        if responder.default_description.is_a?(Array) || responder.default_example_invocation.is_a?(Array)
          error_msg = "#{responder_class.name} descriptions and default_example_invocations sizes don't match"
          expect(responder.default_description.is_a?(Array)).to eq(true), error_msg
          expect(responder.default_example_invocation.is_a?(Array)).to eq(true), error_msg
          expect(responder.default_description.size).to eq(responder.default_example_invocation.size), error_msg
        end
      end
    end
  end

  describe "#required_params" do
    it "should raise error if param is not present" do
      expect {
        subject.required_params(:non_existent)
      }.to raise_error "Configuration Error in Responder: No value for non_existent."
    end

    it "should create reader methods for param values" do
      subject.params = { first_name: "Buffy", last_name: "Summers", location: "Sunnydale" }
      subject.required_params :first_name, :last_name, "location"

      expect(subject.first_name).to eq("Buffy")
      expect(subject.last_name).to eq("Summers")
      expect(subject.location).to eq("Sunnydale")
    end
  end

  describe "#empty_param?" do
    it "should be true when param's value is an empty string" do
      subject.params = { first_name: "", last_name: "       " }

      expect(subject.empty_param?(:first_name)).to be_truthy
      expect(subject.empty_param?(:last_name)).to be_truthy
    end

    it "should be true when param's value is an empty array" do
      subject.params = { values: [] }

      expect(subject.empty_param?(:values)).to be_truthy
    end

    it "should be true when param's value is an empty hash" do
      subject.params = { values: {} }

      expect(subject.empty_param?(:values)).to be_truthy
    end

    it "should be false when param's value is present" do
      subject.params = { labels: ["archived", "accepted"], name: "Buffy", required: {version: "1.0"}, id: 33}

      expect(subject.empty_param?(:labels)).to be_falsy
      expect(subject.empty_param?(:name)).to be_falsy
      expect(subject.empty_param?(:required)).to be_falsy
      expect(subject.empty_param?(:id)).to be_falsy
    end
  end

  describe "#labels_to_add" do
    it "should be [] in no labels" do
      expect(subject.labels_to_add).to eq([])
    end

    it "should return an array of labels to add" do
      subject.params = { add_labels: ["reviewed", "pending-publication"] }

      expect(subject.labels_to_add).to eq(["reviewed", "pending-publication"])
    end
  end

  describe "#labels_to_remove" do
    it "should be [] in no labels" do
      expect(subject.labels_to_remove).to eq([])
    end

    it "should return an array of labels to remove" do
      subject.params = { remove_labels: ["pending-review", "paused"] }

      expect(subject.labels_to_remove).to eq(["pending-review", "paused"])
    end
  end

  describe "labeling" do
    before do
      @responder = described_class.new({ bot_github_user: "botsci" },
                               { add_labels: ["reviewed", "approved", "pending publication"],
                                 remove_labels: ["pending review", "ongoing"] })
      disable_github_calls_for(@responder)
    end

    describe "#process_adding_labels" do
      it "should label issue with defined labels" do
        expect(@responder).to receive(:label_issue).with(["reviewed", "approved", "pending publication"])
        @responder.process_adding_labels
      end
    end

    describe "#process_removing_labels" do
      it "should remove labels from issue" do
        expect(@responder).to receive(:issue_labels).and_return(["pending review", "ongoing"])
        expect(@responder).to receive(:unlabel_issue).with("pending review")
        expect(@responder).to receive(:unlabel_issue).with("ongoing")
        @responder.process_removing_labels
      end

      it "should remove only present labels from issue" do
        expect(@responder).to receive(:issue_labels).and_return(["reviewers assigned", "ongoing"])
        expect(@responder).to_not receive(:unlabel_issue).with("pending review")
        expect(@responder).to receive(:unlabel_issue).with("ongoing")
        @responder.process_removing_labels
      end
    end

    describe "#process_labeling" do
      it "should add and remove labels" do
        expect(@responder).to receive(:process_adding_labels)
        expect(@responder).to receive(:process_removing_labels)
        @responder.process_labeling
      end
    end

    describe "#process_reverse_labeling" do
      it "should reverse add and remove labels" do
        expect(@responder).to receive(:process_labeling)
        @responder.process_reverse_labeling
        expect(@responder.labels_to_add).to eq(["pending review", "ongoing"])
        expect(@responder.labels_to_remove).to eq(["reviewed", "approved", "pending publication"])
      end
    end
  end

  describe "#process_external_service" do
    before do
      @responder = described_class.new({env: { bot_github_user: "botsci" }}, {})
      disable_github_calls_for(@responder)
    end

    it "should do nothing if no external service config present" do
      expect(ExternalServiceWorker).to_not receive(:perform_async)
      expect { @responder.process_external_service({}, {}) }.to_not change(ExternalServiceWorker.jobs, :size)
      expect { @responder.process_external_service("", {}) }.to_not change(ExternalServiceWorker.jobs, :size)
      expect { @responder.process_external_service(nil, {}) }.to_not change(ExternalServiceWorker.jobs, :size)
    end

    it "should add an ExternalServiceWorker to the jobs queue" do
      expect { @responder.process_external_service({ url: "https://theoj.org" }, {}) }.to change(ExternalServiceWorker.jobs, :size).by(1)
    end

    it "should pass right info to the worker" do
      expected_params = { name: "test-service", command: "run tests", url: "http://testing.openjournals.org" }
      expected_locals = { bot_name: "botsci", issue_author: "opener", issue_id: 33, repo: "openjournals/testing", sender: "xuanxu" }
      expect(ExternalServiceWorker).to receive(:perform_async).with(expected_params.transform_keys(&:to_s), expected_locals.transform_keys(&:to_s))
      @responder.process_external_service(expected_params, expected_locals)
    end
  end

  describe "#process_other_responder" do
    before do
      settings = { bot_github_user: "botsci",
                   responders: { github_action:
                                [{ draft_paper: {
                                     command: "generate pdf",
                                     workflow_repo: "openjournals/joss-papers-testing",
                                     workflow_name: "draft-paper.yml",
                                     workflow_ref: "master",
                                     description: "Generates the pdf paper",
                                     message: "Attempting PDF compilation. Reticulating splines etc...",
                                     data_from_issue: ["branch", "issue_id"]}
                                }]}}

      @responder = described_class.new(settings, {})
      @responder.context = OpenStruct.new(sender: "tester", issue_id: 33, issue_body: "", repo: "openjournals/buffy")
      disable_github_calls_for(@responder)
    end

    it "should do nothing if no responder found" do
      expect_any_instance_of(GithubActionResponder).to_not receive(:process_message)

      @responder.process_other_responder({responder_key: :github_action})
    end

    it "should call process_message in found responder" do
      allow_any_instance_of(GithubActionResponder).to receive(:process_message).with("test").and_return("OK")

      result = @responder.process_other_responder({responder_key: :github_action, responder_name: :draft_paper, message: "test"})
      expect(result).to eq("OK")
    end
  end

  describe "#target_repo_value" do
    before do
      @responder = Responder.new({}, {})
      @responder.context = OpenStruct.new(issue_body: "Test Review\n\n ... description ...")
      disable_github_calls_for(@responder)
    end

    it "should be empty if not URL found" do
      expect(@responder.target_repo_value).to be_empty
    end

    it "should use target-repository as the default value for url_field" do
      @responder.context.issue_body +=  "<!--target-repository-->" +
                                        "http://software-to-review.test/git_repo" +
                                        "<!--end-target-repository-->"
      expect(@responder.target_repo_value).to eq("http://software-to-review.test/git_repo")
    end

    it "should use the settings value for url_field if present" do
      @responder.context.issue_body +=  "<!--target-repository-->" +
                                        "http://software-to-review.test/git_repo" +
                                        "<!--end-target-repository-->" +
                                        "<!--paper-url-->https://custom-url.test<!--end-paper-url-->"
      @responder.params = { url_field: "paper-url" }
      expect(@responder.target_repo_value).to eq("https://custom-url.test")
    end
  end

  describe "#branch_name_value" do
    before do
      @responder = Responder.new({}, {})
      @responder.context = OpenStruct.new(issue_body: "Test Review\n\n ... description ...")
      @responder.event_regex = /\A@bot run tests(?: from branch ([\w-]+))?\s*\z/i
      disable_github_calls_for(@responder)
    end
    it "should be empty if no branch found" do
      @responder.match_data = nil
      expect(@responder.branch_name_value).to be_empty
    end

    it "should use branch as the default value for branch_field" do
      @responder.context.issue_body +=  "<!--branch-->dev<!--end-branch-->"
      expect(@responder.branch_name_value).to eq("dev")
    end

    it "should use the settings value for branch_field if present" do
      @responder.context.issue_body +=  "<!--branch-->dev<!--end-branch-->\n" +
                                        "<!--review-branch-->paper<!--end-review-branch-->\n"
      @responder.params = { branch_field: "review-branch" }
      expect(@responder.branch_name_value).to eq("paper")

    end

    it "branch name in command should take precedence over value in the body of the issue" do
      @responder.context.issue_body +=  "<!--branch-->dev<!--end-branch-->"
      command = "@bot run tests from branch custom-branch"
      @responder.match_data = @responder.event_regex.match(command)

      expect(@responder.branch_name_value).to eq("custom-branch")
    end
  end

  describe "#serializable" do
    before do
      @responder = Responder.new({}, {})
      disable_github_calls_for(@responder)
    end

    it "should recursively stringify keys of hashes" do
      expect(@responder.serializable({a: 1, b: {c: "two"}})).to eq({"a" => 1, "b" => { "c" => "two" }})
    end

    it "should stringify keys of hashes inside arrays" do
      expect(@responder.serializable([{a: 1}, 33, "name"])).to eq([{"a" => 1}, 33, "name"])
    end

    it "should stringify Time and Date" do
      time = Time.parse("2023-01-26 12:46:17 +0100")
      expect(@responder.serializable(time)).to eq("2023-01-26 12:46:17 +0100")

      date = Date.parse("2023-01-26")
      expect(@responder.serializable(date)).to eq("2023-01-26")

      datetime = DateTime.parse("2023-01-26T12:49:09+01:00")
      expect(@responder.serializable(datetime)).to eq("2023-01-26T12:49:09+01:00")
    end

    it "should not change string or numeric data" do
      expect(@responder.serializable("hey")).to eq("hey")
      expect(@responder.serializable(42)).to eq(42)
    end
  end
end
