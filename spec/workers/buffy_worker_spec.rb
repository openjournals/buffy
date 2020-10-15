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
end
