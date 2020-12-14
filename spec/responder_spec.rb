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

    it "should be true if there is not restrictions (via :only setting)" do
      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be true if sender is in an authorized team" do
      subject.params = { only: 'editors' }
      allow(subject).to receive(:user_authorized?).with("sender").and_return(true)
      expect(subject.authorized?(@context)).to be_truthy
    end

    it "should be false if sender is not in any authorized team" do
      subject.params = { only: 'editors' }
      allow(subject).to receive(:user_authorized?).with("sender").and_return(false)
      expect(subject.authorized?(@context)).to be_falsey
    end
  end

  describe "#meet_conditions?" do
    before do
      @responder = Responder.new({}, {})
      @responder.context = OpenStruct.new(issue_title: "[REVIEW] Software review",
                                          issue_body: "Test Review\n\n ... description ...\n" +
                                                      "<!--editor-->@editor<!--end-editor-->\n" +
                                                      "<!--editor-2-->L.B.<!--end-editor-2-->\n" +
                                                      "<!--author--><!--end-author-->\n")
      disable_github_calls_for(@responder)
      @context = OpenStruct.new({ if: { title: "[REVIEW]", body:"<!--REVIEW-->", value: "editor" } })
    end

    it "should be true if there is not conditions (via :if setting)" do
      @responder.params = {}
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {}}
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {title: nil, body: nil, value: nil}}
      expect(@responder.meet_conditions?).to be_truthy

      @responder.params = { if: {title: "", body: "", value: ""}}
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be false if title condition is not met" do
      @responder.params = { if: {title: "PRE-REVIEW"} }
      expect(@responder).to receive(:respond).with("I can't do that in this kind of issue")
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if body condition is not met" do
      @responder.params = { if: {body: "ABCDEFG"} }
      expect(@responder).to receive(:respond).with("I can't do that. Data in the body of the issue is incorrect")
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if value condition is not met" do
      @responder.params = { if: {value: "author"} }
      expect(@responder).to receive(:respond).with("That can't be done if there is no author")
      expect(@responder.meet_conditions?).to be_falsy

      @responder.params = { if: {value: "reviewers"} }
      expect(@responder).to receive(:respond).with("That can't be done if there is no reviewers")
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if role_assigned condition is not met" do
      @responder.params = { if: {role_assigned: "editor-2"} } #no username
      expect(@responder).to receive(:respond).with("That can't be done if there is no editor-2 assigned")
      expect(@responder.meet_conditions?).to be_falsy

      @responder.params = { if: {role_assigned: "author"} } # empty
      expect(@responder).to receive(:respond).with("That can't be done if there is no author assigned")
      expect(@responder.meet_conditions?).to be_falsy

      @responder.params = { if: {role_assigned: "reviewers"} } #no present
      expect(@responder).to receive(:respond).with("That can't be done if there is no reviewers assigned")
      expect(@responder.meet_conditions?).to be_falsy
    end

    it "should be false if any condition is not met" do
      @responder.params = { if: {title: "REVIEW", body: "^Test Review", value: "author"} }
      expect(@responder).to receive(:respond)
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

    it "should be true if value condition is met" do
      @responder.params = { if: {value: "editor-2"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true if role_assigned condition is met" do
      @responder.params = { if: {role_assigned: "editor"} }
      expect(@responder).to_not receive(:respond)
      expect(@responder.meet_conditions?).to be_truthy
    end

    it "should be true only if all conditions are met" do
      @responder.params = { if: {title: "REVIEW", body: "^Test Review", value: "editor-2", role_assigned: "editor"} }
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
      subject.params = {only: ['editors', 'owners']}
      allow(subject).to receive(:responds_on?).and_return(true)
      allow(subject).to receive(:responds_to?).and_return(true)
      allow(subject).to receive(:authorized?).and_return(false)
      allow(subject).to receive(:respond).and_return(true)
      allow(subject).to receive(:process_message).never
      expected_msg = "I'm sorry @tester, I'm afraid I can't do that. That's something only editors and owners are allowed to do."
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
                                          repo: "openjournals/buffy",
                                          sender: "user33",
                                          issue_body: "Test Software Review\n\n<!--reviewer-->@xuanxu<!--end-reviewer-->")
    end

    it "should include basic config info" do
      expected_locals = { issue_id: 5, bot_name: "botsci", repo: "openjournals/buffy", sender: "user33" }
      expect(@responder.locals).to eq(expected_locals)
    end

    it "should add info from the issue body if requested" do
      @responder.params = {data_from_issue: ["reviewer"]}
      expected_locals = { issue_id: 5, bot_name: "botsci", repo: "openjournals/buffy", sender: "user33", "reviewer" => "@xuanxu" }
      expect(@responder.locals).to eq(expected_locals)
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

  describe "#description" do
    it "should be present for all responders" do
      ResponderRegistry::RESPONDER_MAPPING.values.each do |responder_class|
        responder = responder_class.new({}, sample_params(responder_class))
        expect(responder.respond_to?(:description)).to eq(true)
        expect(responder.description).to_not be_nil
        expect(responder.description).to_not be_empty
      end
    end
  end

  describe "#example_invocation" do
    it "should be present for all responders" do
      ResponderRegistry::RESPONDER_MAPPING.values.each do |responder_class|
        responder = responder_class.new({}, sample_params(responder_class))
        expect(responder.respond_to?(:example_invocation)).to eq(true)
        expect(responder.example_invocation).to_not be_nil
        expect(responder.example_invocation).to_not be_empty
      end
    end
  end

  describe "multiple descriptions and example invocations" do
    it "should have the same number of each of them" do
      ResponderRegistry::RESPONDER_MAPPING.values.each do |responder_class|
        responder = responder_class.new({}, sample_params(responder_class))
        if responder.description.is_a?(Array) || responder.example_invocation.is_a?(Array)
          error_msg = "#{responder_class.name} descriptions and example_invocations sizes don't match"
          expect(responder.description.is_a?(Array)).to eq(true), error_msg
          expect(responder.example_invocation.is_a?(Array)).to eq(true), error_msg
          expect(responder.description.size).to eq(responder.example_invocation.size), error_msg
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
end
