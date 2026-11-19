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

  describe "#clone_repo_metadata" do
    let(:base) { ["git", "clone", "--quiet", "--depth", "1", "--filter=blob:none", "--no-checkout"] }

    it "should do a shallow clone without file contents" do
      expect(Open3).to receive(:capture3).with(*base, "--", "https://github.com/a/b", "./local/folder").
                       and_return(["", "", OpenStruct.new(success?: true)])
      expect(subject.clone_repo_metadata("https://github.com/a/b", "./local/folder")).to be_truthy
    end

    it "should clone the given branch" do
      expect(Open3).to receive(:capture3).with(*base, "--branch", "joss/paper", "--", "https://github.com/a/b", "./local/folder").
                       and_return(["", "", OpenStruct.new(success?: false)])
      expect(subject.clone_repo_metadata("https://github.com/a/b", "./local/folder", "joss/paper")).to be_falsy
    end

    it "should reject invalid urls and branch names" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.clone_repo_metadata("file:///etc/passwd", "./local/folder")).to be_falsy
      expect(subject.clone_repo_metadata("https://github.com/a/b", "./local/folder", "--upload-pack=x")).to be_falsy
    end
  end

  describe "#repo_files and #read_repo_file" do
    it "should list the regular files, skipping symlinks and submodules, and read one" do
      tree = "100644 blob aaa\ta.md\0" \
             "100755 blob bbb\tbin/run\0" \
             "120000 blob ccc\tpaper.md\0" \
             "160000 commit ddd\tvendor/lib\0" \
             "100644 blob eee\tpaper/paper.md\0"
      expect(Open3).to receive(:capture3).with("git", "-C", "./repo", "ls-tree", "-r", "-z", "HEAD").
                       and_return([tree, "", OpenStruct.new(success?: true)])
      expect(subject.repo_files("./repo")).to eq(["a.md", "bin/run", "paper/paper.md"])

      expect(Open3).to receive(:capture3).with("git", "-C", "./repo", "show", "HEAD:paper/paper.md").
                       and_return(["content", "", OpenStruct.new(success?: true)])
      expect(subject.read_repo_file("./repo", "paper/paper.md")).to eq("content")
    end

    it "should return empty values on errors" do
      allow(Open3).to receive(:capture3).and_return(["", "fatal", OpenStruct.new(success?: false)])
      expect(subject.repo_files("./repo")).to eq([])
      expect(subject.read_repo_file("./repo", "missing.md")).to be_nil
    end
  end

  describe "#clone_repo" do
    it "should return true when successfully cloned a repo to a local path" do
      expect(Open3).to receive(:capture3).
                       with("git", "clone", "--", "http://repository-url.com", "./local/folder").
                       and_return(["OK", "", OpenStruct.new(success?: true)])
      expect(subject.clone_repo("http://repository-url.com", "./local/folder")).to be_truthy
    end

    it "should return false if url is invalid or empty" do
      expect(Open3).to_not receive(:capture3)

      expect(subject.clone_repo("No valid url here", "./local/folder")).to be_falsy
      expect(subject.clone_repo("", "./local/folder")).to be_falsy
      expect(subject.clone_repo(nil, "./local/folder")).to be_falsy
    end

    it "should reject urls with non-http(s) schemes" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.clone_repo("file:///etc/passwd", "./local/folder")).to be_falsy
      expect(subject.clone_repo("ssh://example.com/repo.git", "./local/folder")).to be_falsy
    end

    it "should reject urls without a host" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.clone_repo("http:/repository-url.com", "./local/folder")).to be_falsy
    end

    it "should pass the url to git as an argv argument, not via a shell" do
      malicious_url = "https://github.com/x/y;touch$IFS/tmp/PWNED;"
      expect(Open3).to receive(:capture3).
                       with("git", "clone", "--", malicious_url, "./local/folder").
                       and_return(["", "", OpenStruct.new(success?: false)])
      subject.clone_repo(malicious_url, "./local/folder")
    end

    it "should return false if cloning fails" do
      expect(Open3).to receive(:capture3).
                       with("git", "clone", "--", "http://www.wrong-url.com", "./local/folder").
                       and_return(["", "Invalid URL", OpenStruct.new(success?: false)])
      expect(subject.clone_repo("http://www.wrong-url.com", "./local/folder")).to be_falsy
    end
  end

  describe "#change_branch" do
    it "should switch branch and return true" do
      expect(Open3).to receive(:capture3).
                       with("git", "-C", "local/folder", "switch", "--", "paper-branch").
                       and_return(["OK", "", OpenStruct.new(success?: true)])

      expect(subject.change_branch("paper-branch", "local/folder")).to be_truthy
    end

    it "should return false if command fails" do
      expect(Open3).to receive(:capture3).
                       with("git", "-C", "local/folder", "switch", "--", "newbranch").
                       and_return(["", "No such file or directory", OpenStruct.new(success?: false)])

      expect(subject.change_branch("newbranch", "local/folder")).to be_falsy
    end

    it "should do nothing and return true if branch is nil" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.change_branch(nil, "local/folder")).to be_truthy
      expect(subject.change_branch("", "local/folder")).to be_truthy
    end

    it "should reject branch names containing shell metacharacters" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.change_branch("main; touch /tmp/PWNED", "local/folder")).to be_falsy
      expect(subject.change_branch("main$(touch /tmp/PWNED)", "local/folder")).to be_falsy
      expect(subject.change_branch("main`id`", "local/folder")).to be_falsy
    end

    it "should reject branch names that look like git options" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.change_branch("--upload-pack=evil", "local/folder")).to be_falsy
      expect(subject.change_branch("-x", "local/folder")).to be_falsy
    end
  end

  describe "#run_cloc" do
    it "should run cloc return true" do
      expect(Open3).to receive(:capture3).
                       with("cloc", "--quiet", "local/folder").
                       and_return(["OK", "", OpenStruct.new(success?: true)])

      expect(subject.run_cloc("local/folder")).to be_truthy
    end

    it "should return nil if command fails" do
      expect(Open3).to receive(:capture3).
                       with("cloc", "--quiet", "local/folder").
                       and_return(["", "analysis failed", OpenStruct.new(success?: false)])

      expect(subject.run_cloc("local/folder")).to be_falsy
    end
  end

end
