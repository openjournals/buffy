require_relative "../spec_helper.rb"

describe AuthorsCheckResponder do

  before do
    settings = { env: { bot_github_user: "botsci" }}
    @responder = AuthorsCheckResponder.new(settings, {})
    @responder.context = OpenStruct.new(issue_body: "Test Review\n\n ... description ...")
    disable_github_calls_for(@responder)
  end

  def use_command(msg)
    @responder.match_data = @responder.event_regex.match(msg)
  end

  def add_to_body(values)
    values.each { |name, value| @responder.context.issue_body += "<!--#{name}-->#{value}<!--end-#{name}-->" }
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    context "regex" do
      it "matches the plain command" do
        expect(@responder.event_regex).to match("@botsci check authors")
      end

      it "matches with a final period" do
        expect(@responder.event_regex).to match("@botsci check authors.")
      end

      it "ignores what comes after the first line" do
        expect(@responder.event_regex).to match("@botsci check authors    \r\n ignored part")
      end

      it "is case insensitive" do
        expect(@responder.event_regex).to match("@BotSci Check Authors")
      end

      it "doesn't match other bots" do
        expect(@responder.event_regex).to_not match("@otherbot check authors")
      end

      it "doesn't match the command in the middle of a comment" do
        expect(@responder.event_regex).to_not match("hey @botsci check authors")
      end

      it "doesn't match other commands" do
        expect(@responder.event_regex).to_not match("@botsci check author")
        expect(@responder.event_regex).to_not match("@botsci check authors list")
        expect(@responder.event_regex).to_not match("@botsci check authors with archiv 10.5281/zenodo.1")
      end

      it "matches a branch" do
        expect(@responder.event_regex).to match("@botsci check authors from branch custom/branch")
        expect(@responder.event_regex).to match("@botsci check authors from branch release-1.0_x")
      end

      it "doesn't match a branch with characters that aren't allowed" do
        expect(@responder.event_regex).to_not match("@botsci check authors from branch a;b")
      end

      it "needs a value for each option" do
        expect(@responder.event_regex).to_not match("@botsci check authors from branch ")
        expect(@responder.event_regex).to_not match("@botsci check authors with archive")
        expect(@responder.event_regex).to_not match("@botsci check authors with paper")
      end

      it "matches an archive" do
        expect(@responder.event_regex).to match("@botsci check authors with archive https://zenodo.org/records/123")
        expect(@responder.event_regex).to match("@botsci check authors with archive 10.5281/zenodo.123.")
      end

      it "matches a paper" do
        expect(@responder.event_regex).to match("@botsci check authors with paper docs/paper.md")
      end

      it "matches the options in any order" do
        options = ["from branch joss", "with archive 10.5281/zenodo.1", "with paper docs/paper.md"]
        options.permutation.each do |order|
          expect(@responder.event_regex).to match("@botsci check authors #{order.join(" ")}")
        end
      end

      it "allows several spaces between options" do
        expect(@responder.event_regex).to match("@botsci check authors  from branch joss   with archive 10.5281/zenodo.1")
      end
    end
  end

  describe "#branch_value" do
    it "is the branch from the command" do
      add_to_body("branch" => "issue-branch")
      use_command("@botsci check authors from branch b1")
      expect(@responder.branch_value).to eq("b1")
    end

    it "is the branch from the issue if the command has none" do
      add_to_body("branch" => "issue-branch")
      use_command("@botsci check authors")
      expect(@responder.branch_value).to eq("issue-branch")
    end

    it "uses a custom branch field" do
      @responder.params = { branch_field: "review-branch" }
      add_to_body("review-branch" => "custom")
      use_command("@botsci check authors")
      expect(@responder.branch_value).to eq("custom")
    end

    it "is empty if there's no branch" do
      use_command("@botsci check authors")
      expect(@responder.branch_value).to eq("")
    end

    it "is empty without match data" do
      expect(@responder.branch_value).to eq("")
    end
  end

  describe "#archive_sources" do
    it "includes the archive from the command and from the issue" do
      add_to_body("archive" => "10.5281/zenodo.1")
      use_command("@botsci check authors with archive 10.5281/zenodo.9")
      expect(@responder.archive_sources).to eq({ "command" => "10.5281/zenodo.9", "issue" => "10.5281/zenodo.1", "field" => "archive" })
    end

    it "removes a final period from the command's archive" do
      use_command("@botsci check authors with archive https://zenodo.org/records/9.")
      expect(@responder.archive_sources["command"]).to eq("https://zenodo.org/records/9")
    end

    it "has empty values when there's no archive" do
      use_command("@botsci check authors")
      expect(@responder.archive_sources).to eq({ "command" => "", "issue" => "", "field" => "archive" })
    end

    it "uses the first archive if the command has several" do
      use_command("@botsci check authors with archive 10.5281/zenodo.1 with archive 10.5281/zenodo.2")
      expect(@responder.archive_sources["command"]).to eq("10.5281/zenodo.1")
    end

    it "uses a custom archive field" do
      @responder.params = { archive_field: " zenodo-doi " }
      add_to_body("zenodo-doi" => "10.5281/zenodo.5", "archive" => "10.5281/zenodo.1")
      use_command("@botsci check authors")
      expect(@responder.archive_sources).to eq({ "command" => "", "issue" => "10.5281/zenodo.5", "field" => "zenodo-doi" })
    end

    it "uses the default field when the custom one is blank" do
      @responder.params = { archive_field: "  " }
      expect(@responder.archive_field).to eq("archive")
    end
  end

  describe "#paper_value" do
    it "is empty if the command has no paper" do
      use_command("@botsci check authors")
      expect(@responder.paper_value).to eq("")
    end

    it "is the paper path from the command" do
      use_command("@botsci check authors with paper docs/paper.md")
      expect(@responder.paper_value).to eq("docs/paper.md")
    end

    it "removes a final period" do
      use_command("@botsci check authors with archive 10.5281/zenodo.1 with paper docs/paper.md.")
      expect(@responder.paper_value).to eq("docs/paper.md")
    end

    it "keeps the path as written otherwise" do
      use_command("@botsci check authors with paper ./joss/paper.tex")
      expect(@responder.paper_value).to eq("./joss/paper.tex")
    end
  end

  describe "#ignored_logins" do
    it "includes the reviewers and the editor by default" do
      add_to_body("reviewers-list" => "@Rev1, @rev2", "editor" => "@Editor")
      expect(@responder.ignored_logins).to eq(["rev1", "rev2", "editor"])
    end

    it "uses custom fields" do
      @responder.params = { ignored_users_fields: ["eic", "track-editor"] }
      add_to_body("reviewers-list" => "@rev1", "eic" => "@Boss", "track-editor" => "@track")
      expect(@responder.ignored_logins).to eq(["boss", "track"])
    end

    it "leaves out values that aren't usernames" do
      add_to_body("reviewers-list" => "Pending", "editor" => "TBD")
      expect(@responder.ignored_logins).to eq([])
    end

    it "strips spaces around usernames" do
      add_to_body("reviewers-list" => "  @rev1  ,   @rev2 ")
      expect(@responder.ignored_logins).to eq(["rev1", "rev2"])
    end

    it "is empty when the fields aren't in the issue" do
      expect(@responder.ignored_logins).to eq([])
    end
  end

  describe "help" do
    it "describes the command and its options" do
      expect(@responder.description).to include("Compare the paper's authors")
      expect(@responder.description).to include("non-default branch, with a given Zenodo archive DOI, or with a given paper file")
    end

    it "shows an example for each option" do
      examples = @responder.example_invocation.split("\n")
      expect(examples).to eq(["@botsci check authors",
                              "@botsci check authors from branch custom-branch-name",
                              "@botsci check authors with archive 10.5281/zenodo.123456",
                              "@botsci check authors with paper docs/paper.md"])
      examples.each { |example| expect(@responder.event_regex).to match(example) }
    end
  end

  describe "#process_message" do
    let(:expected_locals) { {"bot_name" => "botsci", "issue_author" => nil, "issue_title" => nil, "issue_id" => nil, "repo" => nil, "sender" => nil} }

    it "should respond an error message if no url" do
      expect(@responder).to receive(:respond).with("I couldn't find the URL for the target repository")
      expect(@responder).to_not receive(:react_to_comment)
      expect(AuthorsCheckWorker).to_not receive(:perform_async)
      @responder.process_message("@botsci check authors")
    end

    it "should call AuthorsCheckWorker with the archive, ignoring reviewers and editor" do
      add_to_body("target-repository" => "https://github.com/a/b", "archive" => "10.5281/zenodo.123",
                  "reviewers-list" => "@Rev1, @rev2", "editor" => "@Editor")

      expect(@responder).to receive(:react_to_comment).with("eyes")
      expect(AuthorsCheckWorker).to receive(:perform_async).with(expected_locals, "https://github.com/a/b", "",
                                                                 { "command" => "", "issue" => "10.5281/zenodo.123", "field" => "archive" },
                                                                 ["rev1", "rev2", "editor"], "")
      @responder.process_message("@botsci check authors")
    end

    it "should use custom fields and branch" do
      @responder.params = { archive_field: "zenodo", ignored_users_fields: ["eic"] }
      add_to_body("target-repository" => "https://github.com/a/b", "zenodo" => "10.5281/zenodo.9",
                  "reviewers-list" => "@rev1", "eic" => "@boss")
      msg = "@botsci check authors from branch paper"
      use_command(msg)

      expect(AuthorsCheckWorker).to receive(:perform_async).with(expected_locals.merge("match_data_1" => " from branch paper"), "https://github.com/a/b", "paper",
                                                                 { "command" => "", "issue" => "10.5281/zenodo.9", "field" => "zenodo" },
                                                                 ["boss"], "")
      @responder.process_message(msg)
    end

    it "should pass all the options from the command" do
      add_to_body("target-repository" => "https://github.com/a/b")
      msg = "@botsci check authors with paper joss/paper.md from branch joss with archive 10.5281/zenodo.7"
      use_command(msg)

      expect(AuthorsCheckWorker).to receive(:perform_async).with(hash_including("bot_name" => "botsci"), "https://github.com/a/b", "joss",
                                                                 { "command" => "10.5281/zenodo.7", "issue" => "", "field" => "archive" },
                                                                 [], "joss/paper.md")
      @responder.process_message(msg)
    end

    it "should use a custom repository field" do
      @responder.params = { url_field: "software-repo" }
      add_to_body("software-repo" => "https://github.com/c/d")
      expect(AuthorsCheckWorker).to receive(:perform_async).with(anything, "https://github.com/c/d", "", anything, [], "")
      @responder.process_message("@botsci check authors")
    end
  end
end
