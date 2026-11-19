require_relative "../spec_helper.rb"

describe AuthorsCheckWorker do

  before do
    @worker = described_class.new
    disable_github_calls_for(@worker)
    allow(@worker).to receive(:setup_local_repo).and_return(true)
  end

  describe "perform" do
    it "should do nothing if error checking out the repo" do
      expect(@worker).to receive(:setup_local_repo).and_return(false)
      expect(PaperFile).to_not receive(:find)
      @worker.perform({}, "url", "main", {}, [])
    end

    it "should respond if there is no paper file" do
      expect(PaperFile).to receive(:find).and_return(PaperFile.new)
      expect(@worker).to receive(:respond).with(/couldn't find a `paper.md` or `paper.tex` file/)
      @worker.perform({}, "url", "main", {}, [])
    end

    it "should respond if the paper has no authors" do
      paper = PaperFile.new("paper.md")
      allow(paper).to receive(:authors).and_return([])
      expect(PaperFile).to receive(:find).and_return(paper)
      expect(@worker).to receive(:respond).with("I couldn't find a list of authors in the paper's metadata.")
      @worker.perform({}, "url", "main", {}, [])
    end

    it "should respond with the authors_check template and cleanup" do
      paper = PaperFile.new("paper.md")
      authors = [{ name: "Jane Doe", orcid: "" }]
      allow(paper).to receive(:authors).and_return(authors)
      expect(PaperFile).to receive(:find).and_return(paper)
      zenodo = [{ name: "Doe, Jane", orcid: "" }]
      github = [{ login: "jd", name: "Jane Doe", contributions: 3 }, { login: "rev", name: "Re View", contributions: 1 }]
      sources = { "command" => "10.5281/zenodo.1", "issue" => "", "field" => "archive" }
      expect(@worker).to receive(:find_archive).with(sources, []).and_return("10.5281/zenodo.1")
      expect(@worker).to receive(:zenodo_creators_for).with("10.5281/zenodo.1", []).and_return(zenodo)
      expect(@worker).to receive(:github_contributors_for).with("https://github.com/a/b", []).and_return(github)

      expected_report = AuthorsChecker.new(paper_authors: authors, zenodo_creators: zenodo, github_contributors: github, ignored_logins: ["rev"]).check
      expect(@worker).to receive(:respond_template).with(:authors_check, { report: expected_report, notes: [] })
      expect(@worker).to receive(:cleanup)

      @worker.perform({}, "https://github.com/a/b", "main", sources, ["rev"])
    end
  end

  describe "authors_check template" do
    it "should render the report" do
      authors = [{ name: "Jane Doe" }, { name: "Antoine André" }, { name: "Raghotham Murthy" }, { name: "Ann Other" }]
      zenodo = [{ name: "Doe, Jane" }, { name: "ANDRE, Antoine" }, { name: "Extra, Person" }]
      github = [{ login: "jd", name: "Jane Doe", contributions: 3 }, { login: "raghotham", name: "", contributions: 2 },
                { login: "x", name: "", contributions: 1 }]
      report = AuthorsChecker.new(paper_authors: authors, zenodo_creators: zenodo, github_contributors: github).check

      expect(@worker).to receive(:respond) do |message|
        expect(message).to include("| Jane Doe | ✅ Doe, Jane | ✅ `@jd` (Jane Doe) |")
        expect(message).to include("| Antoine André | ⚠️ Written differently: ANDRE, Antoine | ❌ Not found |")
        expect(message).to include("| Raghotham Murthy | ❌ Not found | ⚠️ Possibly `@raghotham` |")
        expect(message).to include("**Zenodo authors not listed in the paper:**\n- Extra, Person")
        expect(message).to include("- `@x`: 1 commit\n")
        expect(message).to include("_No archive DOI found_")
      end
      @worker.respond_template(:authors_check, { report: report, notes: ["No archive DOI found"] })
    end

    it "should never mention a user outside a code span" do
      authors = [{ name: "Jane Doe" }, { name: "Bob @acme" }, { name: "Pipe | Name" }]
      zenodo = [{ name: "Doe, Jane" }, { name: "Eve @evil" }]
      github = [{ login: "jd", name: "Jane Doe", contributions: 3 }, { login: "other", name: "Org @someorg", contributions: 2 },
                { login: "noname", name: "", contributions: 1 }]
      report = AuthorsChecker.new(paper_authors: authors, zenodo_creators: zenodo, github_contributors: github).check

      expect(@worker).to receive(:respond) do |message|
        expect(message.gsub(/`[^`]*`/, "")).to_not include("@")
        expect(message).to include("`Bob @acme`")
        expect(message).to include("`@other` (`Org @someorg`)")
        expect(message).to include("- `Eve @evil`")
        expect(message).to include("Pipe \\| Name")
      end
      @worker.respond_template(:authors_check, { report: report, notes: [] })
    end

    it "should show a dash for sources that were not checked" do
      report = AuthorsChecker.new(paper_authors: [{ name: "Jane Doe" }]).check
      expect(@worker).to receive(:respond) do |message|
        expect(message).to include("| Jane Doe | — | — |")
        expect(message).to_not include("not listed in the paper")
        expect(message).to_not include("not matched to a paper author")
      end
      @worker.respond_template(:authors_check, { report: report, notes: [] })
    end
  end

  describe "#find_archive" do
    let(:notes) { [] }
    let(:client) { double("Octokit::Client", issue_comments: []) }

    before do
      @worker.context = OpenStruct.new(bot_name: "botsci", repo: "org/reviews", issue_id: 5)
      allow(@worker).to receive(:github_client).and_return(client)
    end

    def comment(id, login, body)
      OpenStruct.new(id: id, user: OpenStruct.new(login: login), body: body)
    end

    def sources(command: "", issue: "", field: "archive")
      { "command" => command, "issue" => issue, "field" => field }
    end

    it "should use the archive from the command first, without reading comments" do
      expect(client).to_not receive(:issue_comments)
      expect(@worker.find_archive(sources(command: "10.5281/zenodo.1", issue: "10.5281/zenodo.2"), notes)).to eq("10.5281/zenodo.1")
      expect(notes).to be_empty
    end

    it "should then use the most recent 'set ... as archive' command" do
      comments = [comment(1, "editor", "@botsci set 10.5281/zenodo.11 as archive"),
                  comment(2, "editor", "@botsci set 10.5281/zenodo.22 as archive."),
                  comment(3, "author", "New version at https://zenodo.org/records/33"),
                  comment(4, "editor", "@botsci set v1.0 as version"),
                  comment(5, "botsci", "Done! archive is now 10.5281/zenodo.22")]
      expect(client).to receive(:issue_comments).with("org/reviews", 5).and_return(comments)

      expect(@worker.find_archive(sources(issue: "10.5281/zenodo.99"), notes)).to eq("10.5281/zenodo.22")
      expect(notes).to eq(["Using the archive `10.5281/zenodo.22` set in [this comment](https://github.com/org/reviews/issues/5#issuecomment-2)."])
    end

    it "should use the configured archive field name in set commands" do
      comments = [comment(1, "editor", "@botsci set 10.5281/zenodo.11 as zenodo"), comment(2, "editor", "@botsci set 10.5281/zenodo.22 as archive")]
      allow(client).to receive(:issue_comments).and_return(comments)
      expect(@worker.find_archive(sources(field: "zenodo"), notes)).to eq("10.5281/zenodo.11")
    end

    it "should then use the archive value in the issue" do
      allow(client).to receive(:issue_comments).and_return([comment(1, "author", "Archive: 10.5281/zenodo.33")])
      expect(@worker.find_archive(sources(issue: "10.5281/zenodo.99"), notes)).to eq("10.5281/zenodo.99")
      expect(notes).to be_empty
    end

    it "should then use the most recent comment mentioning a Zenodo archive, skipping the bot's comments" do
      comments = [comment(1, "author", "Old archive: https://doi.org/10.5281/zenodo.11"),
                  comment(2, "author", "New archive is at https://zenodo.org/records/22, thanks!"),
                  comment(3, "editor", "Looks good"),
                  comment(4, "botsci", "Reference check: 10.5281/zenodo.33 is OK")]
      allow(client).to receive(:issue_comments).and_return(comments)

      expect(@worker.find_archive(sources(issue: "Pending"), notes)).to eq("zenodo.org/records/22")
      expect(notes).to eq(["Using the Zenodo archive `zenodo.org/records/22` mentioned in [this comment](https://github.com/org/reviews/issues/5#issuecomment-2)."])
    end

    it "should return an empty string if no archive is found" do
      allow(client).to receive(:issue_comments).and_return([comment(1, "author", "@botsci set Pending as archive")])
      expect(@worker.find_archive(sources, notes)).to eq("")
    end

    it "should ignore errors reading the comments" do
      allow(client).to receive(:issue_comments).and_raise(Octokit::NotFound)
      expect(@worker.find_archive(sources(issue: "10.5281/zenodo.99"), notes)).to eq("10.5281/zenodo.99")
    end
  end

  describe "#zenodo_creators_for" do
    let(:notes) { [] }
    before { @worker.context = OpenStruct.new(bot_name: "botsci") }

    it "should skip if there's no archive" do
      expect(@worker.zenodo_creators_for("", notes)).to be_nil
      expect(notes.last).to match(/couldn't find a Zenodo archive in the command, the issue or its comments/)
      expect(notes.last).to include("`@botsci check authors with archive <Zenodo DOI or URL>`")
    end

    it "should skip if the archive is not in Zenodo" do
      expect(@worker.zenodo_creators_for("10.6084/m9.figshare.1", notes)).to be_nil
      expect(notes.last).to match(/is not a Zenodo DOI or URL/)
    end

    it "should accept Zenodo DOIs and record URLs" do
      body = { metadata: { creators: [{ name: "Doe, Jane" }] } }.to_json
      stub_request(:get, "https://zenodo.org/api/records/77").to_return(status: 200, body: body)
      ["10.5281/zenodo.77", "https://doi.org/10.5281/zenodo.77", "https://zenodo.org/records/77",
       "https://zenodo.org/record/77", "zenodo.org/records/77?preview=1"].each do |archive|
        expect(@worker.zenodo_creators_for(archive, notes)).to eq([{ name: "Doe, Jane", orcid: "" }])
      end
      expect(notes).to be_empty
    end

    it "should return the creators of the record, following redirects" do
      stub_request(:get, "https://zenodo.org/api/records/122").to_return(status: 302, headers: { "Location" => "/api/records/123" })
      body = { metadata: { creators: [{ name: "Doe, Jane", orcid: "0000-0001-2345-6789" }, { name: "Smith, John" }] } }.to_json
      stub_request(:get, "https://zenodo.org/api/records/123").to_return(status: 200, body: body)

      creators = @worker.zenodo_creators_for("https://doi.org/10.5281/zenodo.122", notes)
      expect(creators).to eq([{ name: "Doe, Jane", orcid: "0000-0001-2345-6789" }, { name: "Smith, John", orcid: "" }])
      expect(notes).to be_empty
    end

    it "should add a note if the record can't be retrieved" do
      stub_request(:get, "https://zenodo.org/api/records/404").to_return(status: 404)
      expect(@worker.zenodo_creators_for("10.5281/zenodo.404", notes)).to be_nil
      expect(notes.last).to match(/couldn't retrieve the Zenodo record/)
    end
  end

  describe "#github_contributors_for" do
    let(:notes) { [] }
    let(:client) { double("Octokit::Client") }
    before { allow(@worker).to receive(:github_client).and_return(client) }

    it "should skip repositories not in GitHub" do
      expect(@worker.github_contributors_for("https://gitlab.com/a/b", notes)).to be_nil
      expect(notes.last).to match(/not hosted on GitHub/)
    end

    it "should return contributors with their names, excluding bots" do
      contributors = [{ login: "jd", type: "User", contributions: 9 },
                      { login: "dependabot[bot]", type: "Bot", contributions: 4 },
                      { login: "anon", type: "User", contributions: 1 }]
      expect(client).to receive(:contributors).with("a/b.py").and_return(contributors)
      allow(@worker).to receive(:get_user).with("jd").and_return(double(name: "Jane Doe "))
      allow(@worker).to receive(:get_user).with("anon").and_return(nil)

      result = @worker.github_contributors_for("https://github.com/a/b.py.git", notes)
      expect(result).to eq([{ login: "jd", name: "Jane Doe", contributions: 9 }, { login: "anon", name: "", contributions: 1 }])
    end

    it "should add a note if the GitHub API fails" do
      expect(client).to receive(:contributors).and_raise(Octokit::NotFound)
      expect(@worker.github_contributors_for("https://github.com/a/b", notes)).to be_nil
      expect(notes.last).to match(/couldn't retrieve the list of contributors/)
    end
  end
end
