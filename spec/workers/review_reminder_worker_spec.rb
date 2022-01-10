require_relative "../spec_helper.rb"

describe ReviewReminderWorker do

  describe "perform" do
    before do
      @worker = described_class.new
      disable_github_calls_for(@worker)
    end

    it "should do nothing if issue is closed" do
      expect(@worker).to receive(:issue).and_return(double(state: "closed"))
      expect(@worker).to_not receive(:respond)
      expect(@worker.perform({}, "@reviewer33", false)).to eq(false)
    end

    it "should reply message for author" do
      expect(@worker).to receive(:issue).and_return(double(state: "open"))
      expect(@worker).to receive(:respond).with(":wave: @author21, please update us on how things are progressing here (this is an automated reminder).")

      @worker.perform({}, "@author21", true)
    end

    it "should reply message for reviewer" do
      expect(@worker).to receive(:issue).and_return(double(state: "open"))
      expect(@worker).to receive(:respond).with(":wave: @reviewer33, please update us on how your review is going (this is an automated reminder).")

      @worker.perform({}, "@reviewer33", false)
    end
  end

end
