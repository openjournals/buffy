require_relative "../spec_helper.rb"

describe AuthorsCheckResponder do

  before do
    settings = { env: { bot_github_user: "botsci" }}
    @responder = AuthorsCheckResponder.new(settings, {})
    @responder.context = OpenStruct.new(issue_body: "Test Review\n\n ... description ...")
    disable_github_calls_for(@responder)
  end

  describe "listening" do
    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci check authors")
      expect(@responder.event_regex).to match("@botsci check authors.")
      expect(@responder.event_regex).to match("@botsci check authors    \r\n ignored part")
      expect(@responder.event_regex).to match("@botsci check authors from branch custom/branch")
      expect(@responder.event_regex).to_not match("@botsci check authors from branch ")
      expect(@responder.event_regex).to match("@botsci check authors with archive https://zenodo.org/records/123")
      expect(@responder.event_regex).to match("@botsci check authors with archive 10.5281/zenodo.123.")
      expect(@responder.event_regex).to match("@botsci check authors from branch paper with archive 10.5281/zenodo.123")
      expect(@responder.event_regex).to match("@botsci check authors with archive 10.5281/zenodo.123 from branch paper")
      expect(@responder.event_regex).to_not match("@botsci check authors list")
      expect(@responder.event_regex).to_not match("@botsci check authors with archive")
    end
  end

  describe "command options" do
    def options_for(msg)
      @responder.match_data = @responder.event_regex.match(msg)
      [@responder.branch_value, @responder.archive_sources["command"], @responder.archive_sources["issue"]]
    end

    before do
      @responder.context.issue_body += "<!--branch-->issue-branch<!--end-branch-->" +
                                       "<!--archive-->10.5281/zenodo.1<!--end-archive-->"
    end

    it "should use the values from the issue by default" do
      expect(options_for("@botsci check authors")).to eq(["issue-branch", "", "10.5281/zenodo.1"])
    end

    it "should use the branch and archive from the command, in any order" do
      expect(options_for("@botsci check authors with archive https://zenodo.org/records/9.")).to eq(["issue-branch", "https://zenodo.org/records/9", "10.5281/zenodo.1"])
      expect(options_for("@botsci check authors from branch b1 with archive 10.5281/zenodo.9")).to eq(["b1", "10.5281/zenodo.9", "10.5281/zenodo.1"])
      expect(options_for("@botsci check authors with archive 10.5281/zenodo.9 from branch b1")).to eq(["b1", "10.5281/zenodo.9", "10.5281/zenodo.1"])
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
      @responder.context.issue_body += "<!--target-repository-->https://github.com/a/b<!--end-target-repository-->" +
                                       "<!--archive-->10.5281/zenodo.123<!--end-archive-->" +
                                       "<!--reviewers-list-->@Rev1, @rev2<!--end-reviewers-list-->" +
                                       "<!--editor-->@Editor<!--end-editor-->"

      expect(@responder).to receive(:react_to_comment).with("eyes")
      expect(AuthorsCheckWorker).to receive(:perform_async).with(expected_locals, "https://github.com/a/b", "",
                                                                 { "command" => "", "issue" => "10.5281/zenodo.123", "field" => "archive" },
                                                                 ["rev1", "rev2", "editor"])
      @responder.process_message("@botsci check authors")
    end

    it "should use custom fields and branch" do
      @responder.params = { archive_field: "zenodo", ignored_users_fields: ["eic"] }
      @responder.context.issue_body += "<!--target-repository-->https://github.com/a/b<!--end-target-repository-->" +
                                       "<!--zenodo-->10.5281/zenodo.9<!--end-zenodo-->" +
                                       "<!--reviewers-list-->@rev1<!--end-reviewers-list-->" +
                                       "<!--eic-->@boss<!--end-eic-->"
      msg = "@botsci check authors from branch paper"
      @responder.match_data = @responder.event_regex.match(msg)

      expect(AuthorsCheckWorker).to receive(:perform_async).with(expected_locals.merge("match_data_1" => " from branch paper"), "https://github.com/a/b", "paper",
                                                                 { "command" => "", "issue" => "10.5281/zenodo.9", "field" => "zenodo" },
                                                                 ["boss"])
      @responder.process_message(msg)
    end
  end
end
