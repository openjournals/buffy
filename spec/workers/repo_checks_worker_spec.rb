require_relative "../spec_helper.rb"

describe RepoChecksWorker do

  before do
    @worker = described_class.new
    disable_github_calls_for(@worker)
    allow(@worker).to receive(:setup_local_repo).and_return(true)
  end

  describe "perform" do
    it "should setup local repo" do
      expect(@worker).to receive(:setup_local_repo).and_return(true)
      @worker.perform({}, 'url', 'main', [])
    end

    it "should run all available checks if checks is nil/empty" do
      expect(@worker).to receive(:repo_summary)

      @worker.perform({}, 'url', 'main', nil)
    end

    it "should run only specified checks" do
      expect(@worker).to receive(:repo_summary)
      @worker.perform({}, 'url', 'main', ["repo summary"])

      expect(@worker).to_not receive(:repo_summary)
      @worker.perform({}, 'url', 'main', ["whatever", "repo_summary"])
    end

    it "should cleanup created folder" do
      expect(@worker).to receive(:repo_summary).and_return(true)

      expect(@worker).to receive(:cleanup)
      @worker.perform({}, 'url', 'main', nil)
    end
  end

  describe "#repo_summary" do
    before do
      allow(@worker).to receive(:run_cloc).and_return("Ruby 50%, Julia 50%")
      allow(@worker).to receive(:run_gitinspector).and_return("Author: Buffy Summers")
    end

    it "should include cloc report" do
      expect(@worker).to receive(:respond).with(/Ruby 50%, Julia 50%/)
      @worker.repo_summary
    end

    it "should include gitinspector report" do
      expect(@worker).to receive(:respond).with(/Author: Buffy Summers/)
      @worker.repo_summary
    end

    it "should include error message if cloc fails" do
      expect(@worker).to receive(:run_cloc).and_return(nil)
      expect(@worker).to receive(:respond).with(/cloc failed to run/)
      @worker.repo_summary
    end

    it "should include gitinspector report" do
      expect(@worker).to receive(:run_gitinspector).and_return(nil)
      expect(@worker).to receive(:respond).with(/gitinspector failed to run/)
      @worker.repo_summary
    end
  end

end