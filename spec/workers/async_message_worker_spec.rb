require_relative "../spec_helper.rb"

describe AsyncMessageWorker do

  describe "perform" do
    before do
      @worker = described_class.new
      disable_github_calls_for(@worker)
    end

    it "should do nothing if issue is closed" do
      expect(@worker).to receive(:issue).and_return(double(state: "closed"))
      expect(@worker).to_not receive(:respond)

      expect(@worker.perform({}, "Hello @reviewer33")).to eq(false)
    end

    it "should do nothing if message is empty" do
      expect(@worker).to receive(:issue).and_return(double(state: "closed"))
      expect(@worker).to_not receive(:respond)

      expect(@worker.perform({}, "")).to eq(false)
    end

    it "should reply message" do
      expect(@worker).to receive(:issue).and_return(double(state: "open"))
      expect(@worker).to receive(:respond).with(":wave: @author21 how's it going?")

      @worker.perform({}, ":wave: @author21 how's it going?")
    end

    it "should reply message if issue is closed but only_if_open is false" do
      expect(@worker).to receive(:issue).and_return(double(state: "closed"))
      expect(@worker).to receive(:respond).with(":wave: @author21 how's it going?")

      @worker.perform({}, ":wave: @author21 how's it going?", false)
    end
  end

end
