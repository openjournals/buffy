require_relative "../spec_helper.rb"

describe RepoChecksWorker do

  before do
    @worker = described_class.new
    disable_github_calls_for(@worker)
    allow(@worker).to receive(:setup_local_repo).and_return(true)
  end

  describe "perform" do
    it "should setup local repo" do
      expect(@worker).to receive(:setup_local_repo).and_return(false)
      @worker.perform({}, 'url', 'main', [])
    end

    it "should run all available checks if checks is nil/empty" do
      expect(@worker).to receive(:repo_summary)
      expect(@worker).to receive(:detect_languages)
      expect(@worker).to receive(:count_words)
      expect(@worker).to receive(:detect_license)
      expect(@worker).to receive(:detect_statement_of_need)
      expect(@worker).to receive(:detect_first_commit_date)
      expect(@worker).to receive(:detect_repo_dump)

      @worker.perform({}, 'url', 'main', nil)
    end

    it "should run only specified checks" do
      expect(@worker).to receive(:count_words)
      expect(@worker).to receive(:repo_summary)
      expect(@worker).to_not receive(:detect_languages)
      @worker.perform({}, 'url', 'main', ["repo summary"])

      expect(@worker).to_not receive(:repo_summary)
      @worker.perform({}, 'url', 'main', ["wordcount", "whatever", "repo_summary"])
    end

    it "should cleanup created folder" do
      expect(@worker).to receive(:repo_summary).and_return(true)
      expect(@worker).to receive(:detect_languages).and_return(true)
      expect(@worker).to receive(:count_words).and_return(true)
      expect(@worker).to receive(:detect_license).and_return(true)
      expect(@worker).to receive(:detect_statement_of_need).and_return(true)
      expect(@worker).to receive(:detect_first_commit_date).and_return(true)
      expect(@worker).to receive(:detect_repo_dump).and_return(true)

      expect(@worker).to receive(:cleanup)
      @worker.perform({}, 'url', 'main', nil)
    end
  end

  describe "#repo_summary" do
    before do
      allow(@worker).to receive(:run_cloc).and_return("Ruby 50%, Julia 50%")
    end

    it "should include cloc report" do
      expect(@worker).to receive(:respond).with(/Ruby 50%, Julia 50%/)
      @worker.repo_summary
    end

    it "should include error message if cloc fails" do
      expect(@worker).to receive(:run_cloc).and_return(nil)
      expect(@worker).to receive(:respond).with(/cloc failed to run/)
      @worker.repo_summary
    end
  end

  describe "#detect_languages" do
    before do
      repo = OpenStruct.new(head: OpenStruct.new(target_id: 33))
      expected_languages = OpenStruct.new(languages: {"Go"=>21, "HTML"=>664, "Ruby"=>176110, "TeX"=>475, "XML" => 100})
      allow(Rugged::Repository).to receive(:new).and_return(repo)
      allow(Linguist::Repository).to receive(:new).with(repo, 33).and_return(expected_languages)
    end

    it "should label issue with top 3 languages" do
      expect(@worker).to receive(:label_issue).with(["Ruby", "HTML", "TeX"])
      @worker.detect_languages
    end

    it "should not add labels if no languages found" do
      allow(Linguist::Repository).to receive(:new).and_return(OpenStruct.new(languages: {}))
      expect(@worker).to_not receive(:label_issue)
      @worker.detect_languages
    end
  end

  describe "#count_words" do
    it "should do nothing if no paper found" do
      allow(@worker).to receive(:path).and_return("")
      expect(@worker).to_not receive(:respond)
      @worker.count_words
    end

    it "should respond message with wordcount" do
      allow(@worker).to receive(:paper_file).and_return(PaperFile.new("paper/paper.md"))
      expected_wc_command = "cat paper/paper.md | wc -w"
      allow(Open3).to receive(:capture3).with(expected_wc_command).and_return(["  263\n", "", ""])

      expect(@worker).to receive(:respond).with("Wordcount for `paper.md` is 263")
      @worker.count_words
    end
  end

  describe "#detect_license" do
    it "should do nothing if license found" do
      project = OpenStruct.new(license: "MIT")
      allow(Licensee).to receive(:project).and_return(project)
      expect(@worker).to_not receive(:respond)
      @worker.detect_license
    end

    it "should respond error message if no license found" do
      project = OpenStruct.new(license: nil)
      allow(Licensee).to receive(:project).and_return(project)
      expect(@worker).to receive(:respond).with("Failed to discover a valid open source license")
      @worker.detect_license
    end
  end

  describe "#detect_statement_of_need" do
    it "should do nothing if statement of need found" do
      paper = OpenStruct.new(text: "# Statement of Need\nVery important research")
      allow(PaperFile).to receive(:find).with(@worker.path).and_return(paper)

      expect(@worker).to_not receive(:respond)
      @worker.detect_statement_of_need
    end

    it "should respond error message if no statement of need found" do
      paper = OpenStruct.new(text: "Very important research")
      allow(PaperFile).to receive(:find).with(@worker.path).and_return(paper)
      expect(@worker).to receive(:respond).with("Failed to discover a `Statement of need` section in paper")
      @worker.detect_statement_of_need
    end
  end

  describe "#paper_file" do
    it "should try to find a paper in the path" do
      expect(PaperFile).to receive(:find).with(@worker.path).and_return("PaperFile OK")

      expect(@worker.paper_file).to eq("PaperFile OK")
    end
  end

  describe "#detect_first_commit_date" do
    it "should respond with the first commit date" do
      # Mock repository and commit structure
      first_commit = OpenStruct.new(time: Time.new(2020, 1, 15, 10, 0, 0))
      second_commit = OpenStruct.new(time: Time.new(2021, 6, 20, 14, 30, 0))

      walker = [second_commit, first_commit]
      mock_walker = double('walker')
      allow(mock_walker).to receive(:push)
      allow(mock_walker).to receive(:each).and_yield(second_commit).and_yield(first_commit)

      repo = OpenStruct.new(head: OpenStruct.new(target_id: 123))
      allow(Rugged::Repository).to receive(:new).and_return(repo)
      allow(Rugged::Walker).to receive(:new).and_return(mock_walker)

      expect(@worker).to receive(:respond).with("First public commit was made on January 15, 2020")
      @worker.detect_first_commit_date
    end

    it "should respond with error if no commits found" do
      mock_walker = double('walker')
      allow(mock_walker).to receive(:push)
      allow(mock_walker).to receive(:each)

      repo = OpenStruct.new(head: OpenStruct.new(target_id: 123))
      allow(Rugged::Repository).to receive(:new).and_return(repo)
      allow(Rugged::Walker).to receive(:new).and_return(mock_walker)

      expect(@worker).to receive(:respond).with("Could not determine first commit date")
      @worker.detect_first_commit_date
    end
  end

  describe "#detect_repo_dump" do
    before do
      allow(@worker).to receive(:path).and_return("/fake/path")
    end

    it "should detect healthy distribution when code is spread evenly" do
      # Mock commits spread over time with even distribution (each < 25% of total)
      commits = [
        create_mock_commit(Time.new(2020, 1, 1), 50, "abc1234"),
        create_mock_commit(Time.new(2020, 1, 4), 50, "def5678"),
        create_mock_commit(Time.new(2020, 1, 7), 50, "ghi9012"),
        create_mock_commit(Time.new(2020, 1, 10), 50, "jkl3456"),
        create_mock_commit(Time.new(2020, 1, 13), 50, "mno7890"),
        create_mock_commit(Time.new(2020, 1, 16), 50, "pqr1234")
      ]

      setup_repo_dump_mocks(commits)

      expect(@worker).to receive(:respond).with(/Healthy distribution/)
      @worker.detect_repo_dump
    end

    it "should detect moderate repo dump signal (25-49%)" do
      # Mock commits with 30% in 48-hour window
      commits = [
        create_mock_commit(Time.new(2020, 1, 1), 300, "abc1234"),
        create_mock_commit(Time.new(2020, 1, 2), 0, "def5678"),
        create_mock_commit(Time.new(2020, 1, 5), 200, "ghi9012"),
        create_mock_commit(Time.new(2020, 1, 10), 200, "jkl3456"),
        create_mock_commit(Time.new(2020, 1, 15), 300, "mno7890")
      ]

      setup_repo_dump_mocks(commits)

      expect(@worker).to receive(:respond).with(/Moderate repo dump signal/)
      @worker.detect_repo_dump
    end

    it "should detect strong repo dump signal (50-74%)" do
      # Mock commits with 60% in 48-hour window
      commits = [
        create_mock_commit(Time.new(2020, 1, 1), 600, "abc1234"),
        create_mock_commit(Time.new(2020, 1, 2), 0, "def5678"),
        create_mock_commit(Time.new(2020, 1, 10), 200, "ghi9012"),
        create_mock_commit(Time.new(2020, 1, 15), 200, "jkl3456")
      ]

      setup_repo_dump_mocks(commits)

      expect(@worker).to receive(:respond).with(/Strong repo dump signal/)
      @worker.detect_repo_dump
    end

    it "should detect critical repo dump signal (75%+)" do
      # Mock commits with 80% in 48-hour window
      commits = [
        create_mock_commit(Time.new(2020, 1, 1), 800, "abc1234"),
        create_mock_commit(Time.new(2020, 1, 2), 0, "def5678"),
        create_mock_commit(Time.new(2020, 1, 10), 100, "ghi9012"),
        create_mock_commit(Time.new(2020, 1, 15), 100, "jkl3456")
      ]

      setup_repo_dump_mocks(commits)

      expect(@worker).to receive(:respond).with(/Critical repo dump signal/)
      @worker.detect_repo_dump
    end

    it "should handle repositories with no commit data" do
      setup_repo_dump_mocks([])

      expect(@worker).to receive(:respond).with("No commit data available for repo dump analysis")
      @worker.detect_repo_dump
    end

    def create_mock_commit(time, additions, sha)
      parent = double('parent')
      diff = double('diff')
      allow(diff).to receive(:stat).and_return([additions, 0, 0])
      allow(parent).to receive(:diff).and_return(diff)

      OpenStruct.new(
        time: time,
        parents: [parent],
        oid: sha
      )
    end

    def setup_repo_dump_mocks(commits)
      mock_walker = double('walker')
      allow(mock_walker).to receive(:push)

      if commits.empty?
        allow(mock_walker).to receive(:each)
      else
        allow(mock_walker).to receive(:each) do |&block|
          commits.each { |c| block.call(c) }
        end
      end

      repo = OpenStruct.new(head: OpenStruct.new(target_id: 123))
      allow(Rugged::Repository).to receive(:new).and_return(repo)
      allow(Rugged::Walker).to receive(:new).and_return(mock_walker)
    end
  end
end