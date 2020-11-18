require_relative "../spec_helper.rb"

class PathTestingWorker < BuffyWorker
  def perform
    path
  end
end

describe BuffyWorker do
  it "should use the job id in the path" do
    job_id = PathTestingWorker.perform_async
    path   = PathTestingWorker.perform_one
    expect(path).to eq("tmp/#{job_id}")
  end

  it "should be aware of the RACK_ENV" do
    expect(BuffyWorker.new.rack_environment).to eq('test')
  end

  describe "#load_context_and_settings" do
    before do
      config = { 'issue_id' => 333, 'repo' => 'openjournals/testing' }
      @worker = BuffyWorker.new
      @worker.load_context_and_settings(config)
    end

    it "should read settings file" do
      expect(@worker.buffy_settings['gh_secret_token']).to eq('secret-token')
      expect(@worker.buffy_settings['teams']['editors']).to eq(2009411)
    end

    it "should load context" do
      expect(@worker.context[:issue_id]).to eq(333)
      expect(@worker.context[:repo]).to eq('openjournals/testing')
    end

    it "should load settings" do
      expect(@worker.settings[:templates_path]).to eq('.buffy/templates')
      expect(@worker.settings[:gh_access_token]).to eq('secret-access')
    end
  end

  describe "#setup_local_repo" do
    before do
      @worker = BuffyWorker.new
    end

    it "should error if url is not a git repo" do
      msg_no_repo = "Downloading of the repository failed. Please make sure the URL is correct."
      expect(@worker).to receive(:clone_repo).and_return(false)
      expect(@worker).to_not receive(:change_branch)
      expect(@worker).to receive(:respond).with(msg_no_repo)

      expect(@worker.setup_local_repo("wrong_url", "main")).to be_falsy
    end

    it "should error if branch is not present" do
      msg_no_branch = "Couldn't check the bibtex because branch name is incorrect: wrong_branch"
      expect(@worker).to receive(:clone_repo).and_return(true)
      expect(@worker).to receive(:change_branch).and_return(false)
      expect(@worker).to receive(:respond).with(msg_no_branch)

      expect(@worker.setup_local_repo("correct_url", "wrong_branch")).to be_falsy
    end

    it "should not checkout branch if branch is nil" do
      expect(@worker).to receive(:clone_repo).and_return(true)
      expect(Open3).to_not receive(:capture3)
      expect(@worker).to_not receive(:respond)

      expect(@worker.setup_local_repo("correct_url", nil)).to be_truthy
    end

    it "should clone repo and checkout branch" do
      msg_no_branch = "Couldn't check the bibtex because branch name is incorrect"
      expect(@worker).to receive(:clone_repo).and_return(true)
      expect(@worker).to receive(:change_branch).and_return(true)
      expect(@worker).to_not receive(:respond)

      expect(@worker.setup_local_repo("correct_url", "correct_branch")).to be_truthy
    end
  end

  describe "#cleanup" do
    before do
      @worker = BuffyWorker.new
    end

    it "should remove the worker folder if it exists" do
      expect(@worker).to receive(:path).twice.and_return("path/to/worker/dir")
      expect(Dir).to receive(:exist?).with("path/to/worker/dir").and_return(true)
      expect(FileUtils).to receive(:rm_rf).with("path/to/worker/dir")

      @worker.cleanup
    end

    it "should do nothing if the worker folder doesn't exists" do
      expect(@worker).to receive(:path).and_return("path/to/worker/dir")
      expect(Dir).to receive(:exist?).with("path/to/worker/dir").and_return(false)
      expect(FileUtils).to_not receive(:rm_rf)

      @worker.cleanup
    end
  end
end
