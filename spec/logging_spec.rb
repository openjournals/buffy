require_relative "./spec_helper.rb"

describe "Logger" do

  subject do
    Responder.new({}, {})
  end

  describe "#logger" do
    it "should return a Logger instance" do
      expect(subject.logger).to be_kind_of(Logger)
    end
  end
end