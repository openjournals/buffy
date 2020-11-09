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

    it "should do nothing and return true if branch is nil" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.change_branch(nil, "local/folder")).to be_truthy
      expect(subject.change_branch("", "local/folder")).to be_truthy
    end
  end

end
