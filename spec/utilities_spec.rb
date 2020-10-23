require_relative "./spec_helper.rb"

class TestingUtilities
  require_relative '../app/lib/utilities'
  include Utilities
end

describe "Utilities" do

  subject do
    TestingUtilities.new
  end

  before do
    disable_github_calls_for(subject)
  end

  describe "#levenshtein_distance" do
    it "should measuring the difference between strings" do
      expect(subject.levenshtein_distance("Hello", "Hello")).to eq 0
      expect(subject.levenshtein_distance("Hello", "hello")).to eq 1
      expect(subject.levenshtein_distance("low data", "raw data")).to eq 2
      expect(subject.levenshtein_distance("Sunday", "Saturday")).to eq 3
    end
  end

  describe "#similar?" do
    it "should be true if levenshtein distance is less than 3" do
      expect(subject.similar?("Hello", "Hello")).to be_truthy
      expect(subject.similar?("Hello", "hello")).to be_truthy
      expect(subject.similar?("low data", "raw data")).to be_truthy
    end

    it "should be false if levenshtein distance is 3 or bigger" do
      expect(subject.similar?("Sunday", "Saturday")).to be_falsy
      expect(subject.similar?("Way too", "different")).to be_falsy
    end
  end

  describe "#find_paper_file" do
    it "should return paper path if present" do
      allow(Find).to receive(:find).with("/repo/path/").and_return(["lib/papers", "./docs/paper.md", "app"])
      expect(subject.find_paper_file("/repo/path/")).to eq "./docs/paper.md"
    end

    it "should return nil if no paper file found" do
      allow(Find).to receive(:find).with("/repo/path/").and_return(["lib/papers.pdf", "./docs", "app"])
      expect(subject.find_paper_file("/repo/path/")).to be_nil
    end
  end

  describe "#clone_repo" do
    it "should return true when succesfully cloned a repo to a local path" do
      expect(Open3).to receive(:capture3).
                       with("git clone http:/repository-url.com ./local/folder").
                       and_return(["OK", "", OpenStruct.new(success?: true)])
      expect(subject.clone_repo("http:/repository-url.com", "./local/folder")).to be_truthy
    end

    it "should return false if url is invalid or empty" do
      expect(Open3).to_not receive(:capture3)

      expect(subject.clone_repo("No valid url here", "./local/folder")).to be_falsy
      expect(subject.clone_repo("", "./local/folder")).to be_falsy
      expect(subject.clone_repo(nil, "./local/folder")).to be_falsy
    end

    it "should return false if cloning fails" do
      expect(Open3).to receive(:capture3).
                       with("git clone http://www.wrong-url.com ./local/folder").
                       and_return(["", "Invalid URL", OpenStruct.new(success?: false)])
      expect(subject.clone_repo("http://www.wrong-url.com", "./local/folder")).to be_falsy
    end
  end

  describe "#change_branch" do
    it "should checkout branch and return true" do
      expect(Open3).to receive(:capture3).
                       with("git -C local/folder checkout paper-branch").
                       and_return(["OK", "", OpenStruct.new(success?: true)])

      expect(subject.change_branch("paper-branch", "local/folder")).to be_truthy
    end

    it "should return false if command fails" do
      expect(Open3).to receive(:capture3).
                       with("git -C local/folder checkout newbranch").
                       and_return(["", "No such file or directory", OpenStruct.new(success?: false)])

      expect(subject.change_branch("newbranch", "local/folder")).to be_falsy
    end
  end

end
