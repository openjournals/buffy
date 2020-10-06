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
end
