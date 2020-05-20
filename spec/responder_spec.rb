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
      expect(subject.call("testing", context)).to be false
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

  describe "description" do
    it "should be present for all responders" do
      ResponderRegistry::RESPONDER_MAPPING.values.each do |responder_class|
        responder = responder_class.new({}, {})
        expect(responder.respond_to?(:description)).to eq(true)
        expect(responder.description).to_not be_nil
        expect(responder.description).to_not be_empty
      end
    end
  end

  describe "example_invocation" do
    it "should be present for all responders" do
      ResponderRegistry::RESPONDER_MAPPING.values.each do |responder_class|
        responder = responder_class.new({}, {})
        expect(responder.respond_to?(:example_invocation)).to eq(true)
        expect(responder.example_invocation).to_not be_nil
        expect(responder.example_invocation).to_not be_empty
      end
    end
  end
end
