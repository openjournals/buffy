require_relative "../spec_helper.rb"

describe AuthorsCheckWorker do

  before do
    @worker = described_class.new
    @worker.context = OpenStruct.new(bot_name: "botsci")
    disable_github_calls_for(@worker)
    allow(@worker).to receive(:load_context_and_env)
  end

  let(:paper_hint) { "Sorry, I couldn't figure out the right paper file. Please name it explicitly: `@botsci check authors with paper <path to paper.md>`" }
  let(:archive_hint) { "Sorry, I couldn't figure out the Zenodo archive. Please name it explicitly: `@botsci check authors with archive <Zenodo DOI or URL>`" }

  describe "perform" do
    before do
      # Never let perform remove anything outside a test folder (jid is nil in tests)
      allow(@worker).to receive(:cleanup)
      allow(@worker).to receive(:find_archive).and_return("")
    end

    it "should respond with the error and cleanup if the paper can't be read" do
      expect(@worker).to receive(:paper_file_from_repo).with("url", "main", "").and_return([nil, "Downloading the repository failed."])
      expect(@worker).to receive(:respond).with("Downloading the repository failed.")
      expect(@worker).to receive(:cleanup)
      @worker.perform({}, "url", "main", {}, [])
    end

    it "should respond if the paper has no authors" do
      expect(@worker).to receive(:paper_file_from_repo).and_return([PaperFile.new("docs/paper.md").tap { |p| p.metadata_content = "title: x" }, nil])
      expect(@worker).to receive(:respond).with("I couldn't find a list of authors in `docs/paper.md`. #{paper_hint}")
      @worker.perform({}, "url", "main", {}, [])
    end

    it "should pass the paper path from the command" do
      expect(@worker).to receive(:paper_file_from_repo).with("url", "main", "docs/paper.md").and_return([nil, "error"])
      expect(@worker).to receive(:respond).with("error")
      @worker.perform({}, "url", "main", {}, [], "docs/paper.md")
    end

    it "should respond with the error and stop if the archive is unclear" do
      expect(@worker).to receive(:find_archive).and_raise(AuthorsCheckWorker::ArchiveConflict, "Please set the archive")
      expect(@worker).to_not receive(:paper_file_from_repo)
      expect(@worker).to receive(:respond).with("Please set the archive")
      expect(@worker).to receive(:cleanup)
      @worker.perform({}, "url", "main", {}, [])
    end

    it "should respond with the authors_check template and cleanup" do
      paper = PaperFile.new("paper.md")
      authors = [{ name: "Jane Doe", orcid: "" }]
      allow(paper).to receive(:authors).and_return(authors)
      expect(@worker).to receive(:paper_file_from_repo).with("https://github.com/a/b", "main", "").and_return([paper, nil])
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

  describe "#paper_file_from_repo" do
    before { allow(@worker).to receive(:path).and_return(@dir = Dir.mktmpdir) }
    after { FileUtils.rm_rf(@dir) }

    it "should return an error if the repo can't be cloned" do
      expect(@worker).to receive(:clone_repo_metadata).with("url", @dir, "main").and_return(false)
      expect(@worker.paper_file_from_repo("url", "main")).to eq([nil, "Downloading the repository failed. Please make sure the URL and the branch name are correct. " +
                                                                      "To use a different branch, run `@botsci check authors from branch <branch name>`."])
    end

    it "should return an error if there's no paper" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).with(@dir).and_return(["README.md", "src/paper_utils.py"])
      expect(@worker.paper_file_from_repo("url", nil)).to eq([nil, "I couldn't find a `paper.md` or `paper.tex` file in the repository. #{paper_hint}"])
    end

    it "should fetch only the paper's metadata, without writing anything to disk" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["README.md", "docs/paper/paper.md", "docs/paper/paper.bib"])
      expect(@worker).to receive(:read_repo_file).with(@dir, "docs/paper/paper.md").and_return("---\nauthors:\n  - name: Jane Doe\n---\n")

      paper, error = @worker.paper_file_from_repo("url", nil)
      expect(error).to be_nil
      expect(paper.authors).to eq([{ name: "Jane Doe", orcid: "" }])
      expect(Dir.children(@dir)).to be_empty
    end

    it "should not write outside the folder, whatever the paths in the repo" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["a/../../../paper.md"])
      allow(@worker).to receive(:read_repo_file).and_return("authors:\n  - name: Jane Doe\n")

      expect(File).to_not receive(:write)
      expect(@worker.paper_file_from_repo("url", nil).first.authors).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should prefer the paper closest to the root of the repository" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["docs/paper.md", "examples/demo/paper.md", "paper.md", "z/paper.md"])
      expect(@worker).to receive(:read_repo_file).with(@dir, "paper.md").and_return("authors:\n  - name: Root Author\n")
      expect(@worker.paper_file_from_repo("url", nil).first.authors.first[:name]).to eq("Root Author")
    end

    it "should fetch paper.yml for LaTeX papers" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["paper/paper.tex", "paper/paper.yml"])
      expect(@worker).to receive(:read_repo_file).with(@dir, "paper/paper.yml").and_return("authors:\n  - name: Ada Lovelace\n")

      expect(@worker.paper_file_from_repo("url", nil).first.authors).to eq([{ name: "Ada Lovelace", orcid: "" }])
    end

    it "should return an error if the metadata file can't be read" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["paper/paper.tex"])
      allow(@worker).to receive(:read_repo_file).and_return(nil)
      expect(@worker.paper_file_from_repo("url", nil)).to eq([nil, "I couldn't read `paper/paper.yml` from the repository. #{paper_hint}"])
    end

    it "should use the paper given in the command" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["paper.md", "joss/manuscript.md"])
      expect(@worker).to receive(:read_repo_file).with(@dir, "joss/manuscript.md").and_return("authors:\n  - name: Jane Doe\n")

      paper, error = @worker.paper_file_from_repo("url", nil, "./joss/manuscript.md")
      expect(error).to be_nil
      expect(paper.paper_path).to eq("joss/manuscript.md")
    end

    it "should use paper.yml next to a LaTeX paper given in the command" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["tex/main.tex", "tex/paper.yml"])
      expect(@worker).to receive(:read_repo_file).with(@dir, "tex/paper.yml").and_return("authors:\n  - Jane Doe\n")
      expect(@worker.paper_file_from_repo("url", nil, "tex/main.tex").first.authors).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should return an error if the paper given in the command isn't in the repository" do
      allow(@worker).to receive(:clone_repo_metadata).and_return(true)
      allow(@worker).to receive(:repo_files).and_return(["paper.md"])
      expect(@worker).to_not receive(:read_repo_file)
      expect(@worker.paper_file_from_repo("url", nil, "../../etc/passwd")).to eq([nil, "I couldn't find `../../etc/passwd` in the repository. #{paper_hint}"])
    end

    it "should work with a real repository, including symlinks and file names that aren't UTF-8" do
      source = File.join(@dir, "source")
      FileUtils.mkdir_p(File.join(source, "paper"))
      File.write(File.join(source, "paper", "paper.md"), "---\nauthors:\n  - name: Jane Doe\n---\n")
      File.symlink("paper/paper.md", File.join(source, "paper.md"))
      system("git", "-C", source, "init", "-q", exception: true)
      system("git", "-C", source, "add", "-A", exception: true)
      # Some file systems refuse file names that aren't UTF-8, so add one straight to git's index
      blob = IO.popen(["git", "-C", source, "hash-object", "-w", "--stdin"], "r+") { |io| io.write("x"); io.close_write; io.read.strip }
      system("git", "-C", source, "update-index", "--add", "--cacheinfo", "100644,#{blob},r\xE9sum\xE9.txt".b, exception: true)
      system("git", "-C", source, "-c", "user.name=T", "-c", "user.email=t@example.com", "commit", "-q", "-m", "init", exception: true)

      clone = File.join(@dir, "clone")
      allow(@worker).to receive(:path).and_return(clone)
      # clone_repo_metadata only accepts http(s) urls, so make the same kind of clone from the local repo
      allow(@worker).to receive(:clone_repo_metadata) do
        system("git", "-c", "uploadpack.allowFilter=true", "clone", "-q", "--depth", "1", "--filter=blob:none", "--no-checkout",
               "file://#{source}", clone, exception: true)
      end

      paper, error = @worker.paper_file_from_repo("url", nil)
      expect(error).to be_nil
      expect(paper.paper_path).to eq("paper/paper.md")
      expect(paper.authors).to eq([{ name: "Jane Doe", orcid: "" }])
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
        expect(message.gsub(/`[^`\n]*`/, "")).to_not match(/[@#]/)
        expect(message).to include("`Bob @acme`")
        expect(message).to include("`@other` (`Org @someorg`)")
        expect(message).to include("- `Eve @evil`")
        expect(message).to include("Pipe \\| Name")
      end
      @worker.respond_template(:authors_check, { report: report, notes: [] })
    end

    it "should keep names with line breaks inside their code span" do
      authors = [{ name: "Bob Builder\n\n@octocat thanks" }, { name: "Ann\u2028@evil" }, { name: "See org/repo#1" }]
      zenodo = [{ name: "Eve\r\n@someone" }]
      github = [{ login: "x", name: "Mal\n@lory", contributions: 1 }]
      report = AuthorsChecker.new(paper_authors: authors, zenodo_creators: zenodo, github_contributors: github).check

      expect(@worker).to receive(:respond) do |message|
        expect(message.gsub(/`[^`\n]*`/, "")).to_not match(/[@#]/)
        expect(message).to include("| `Bob Builder @octocat thanks` |")
        expect(message).to include("`See org/repo#1`")
        expect(message).to include("- `Eve @someone`")
        expect(message).to include("`@x` (`Mal @lory`)")
      end
      @worker.respond_template(:authors_check, { report: report, notes: [] })
    end

    it "should show both ORCIDs when they differ" do
      authors = [{ name: "Jane Doe", orcid: "0000-0001-2345-6789" }]
      zenodo = [{ name: "Doe, Jane", orcid: "0000-0009-8765-4321" }]
      report = AuthorsChecker.new(paper_authors: authors, zenodo_creators: zenodo).check
      expect(@worker).to receive(:respond) do |message|
        expect(message).to include("| Jane Doe | ⚠️ Different ORCID: Doe, Jane has 0000-0009-8765-4321 (paper: 0000-0001-2345-6789) | — |")
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

    it "should use the archive in the issue when it matches the most recent 'set ... as archive' command" do
      comments = [comment(1, "editor", "@botsci set 10.5281/zenodo.11 as archive"),
                  comment(2, "editor", "@botsci set 10.5281/zenodo.22 as archive."),
                  comment(3, "editor", "@botsci set v1.0 as version"),
                  comment(4, "botsci", "Done! archive is now 10.5281/zenodo.22")]
      expect(client).to receive(:issue_comments).with("org/reviews", 5).and_return(comments)

      expect(@worker.find_archive(sources(issue: "10.5281/zenodo.22"), notes)).to eq("10.5281/zenodo.22")
      expect(notes).to be_empty
    end

    it "should raise an error if the most recent 'set ... as archive' command doesn't match the issue" do
      comments = [comment(1, "editor", "@botsci set 10.5281/zenodo.11 as archive"),
                  comment(2, "author", "@botsci set 10.5281/zenodo.999 as archive")]
      allow(client).to receive(:issue_comments).and_return(comments)

      expect { @worker.find_archive(sources(issue: "10.5281/zenodo.11"), notes) }.to raise_error(AuthorsCheckWorker::ArchiveConflict) do |error|
        expect(error.message).to include("[this comment](https://github.com/org/reviews/issues/5#issuecomment-2)")
        expect(error.message).to include("sets `10.5281/zenodo.999`, but the issue has `10.5281/zenodo.11`")
        expect(error.message).to include("Please set the right archive in the issue with `@botsci set <DOI> as archive`")
        expect(error.message.gsub(/`[^`\n]*`/, "")).to_not include("@")
      end
    end

    it "should raise an error if a 'set ... as archive' command didn't make it to the issue" do
      allow(client).to receive(:issue_comments).and_return([comment(1, "author", "@botsci set 10.5281/zenodo.999 as archive")])
      expect { @worker.find_archive(sources(issue: "Pending"), notes) }.to raise_error(AuthorsCheckWorker::ArchiveConflict, /the issue has no archive set/)
    end

    it "should not raise an error if the archive is given in the command" do
      allow(client).to receive(:issue_comments).and_return([comment(1, "author", "@botsci set 10.5281/zenodo.999 as archive")])
      expect(@worker.find_archive(sources(command: "10.5281/zenodo.1"), notes)).to eq("10.5281/zenodo.1")
    end

    it "should ignore earlier set commands if the most recent one is Pending" do
      comments = [comment(1, "editor", "@botsci set 10.5281/zenodo.111 as archive"),
                  comment(2, "editor", "@botsci set Pending as archive"),
                  comment(3, "author", "New archive: 10.5281/zenodo.222")]
      allow(client).to receive(:issue_comments).and_return(comments)
      expect(@worker.find_archive(sources(issue: "Pending"), notes)).to eq("10.5281/zenodo.222")
    end

    it "should use the configured archive field name in set commands" do
      comments = [comment(1, "editor", "@botsci set 10.5281/zenodo.11 as zenodo"), comment(2, "editor", "@botsci set 10.5281/zenodo.22 as archive")]
      allow(client).to receive(:issue_comments).and_return(comments)
      expect { @worker.find_archive(sources(field: "zenodo", issue: "10.5281/zenodo.22"), notes) }.to raise_error(AuthorsCheckWorker::ArchiveConflict, /set \.\.\. as zenodo/)
      expect(@worker.find_archive(sources(field: "zenodo", issue: "10.5281/zenodo.11"), notes)).to eq("10.5281/zenodo.11")
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

    it "should use the last Zenodo reference in a comment, and ignore sandbox records" do
      comments = [comment(1, "author", "Old: 10.5281/zenodo.1, new: https://zenodo.org/records/2, test: https://sandbox.zenodo.org/records/3")]
      allow(client).to receive(:issue_comments).and_return(comments)
      expect(@worker.find_archive(sources, notes)).to eq("zenodo.org/records/2")
    end

    it "should return an empty string if no archive is found" do
      allow(client).to receive(:issue_comments).and_return([comment(1, "author", "@botsci set Pending as archive")])
      expect(@worker.find_archive(sources, notes)).to eq("")
    end

    it "should ignore errors reading the comments" do
      allow(client).to receive(:issue_comments).and_raise(Octokit::NotFound)
      expect(@worker.find_archive(sources(issue: "10.5281/zenodo.99"), notes)).to eq("10.5281/zenodo.99")
      @worker.instance_variable_set(:@human_comments, nil)
      allow(client).to receive(:issue_comments).and_raise(Faraday::ConnectionFailed.new("down"))
      expect(@worker.find_archive(sources(issue: "10.5281/zenodo.98"), notes)).to eq("10.5281/zenodo.98")
    end
  end

  describe "#zenodo_creators_for" do
    let(:notes) { [] }
    before { @worker.context = OpenStruct.new(bot_name: "botsci") }

    it "should skip if there's no archive" do
      expect(@worker.zenodo_creators_for("", notes)).to be_nil
      expect(notes.last).to match(/couldn't find a Zenodo archive in the command, the issue or its comments/)
      expect(notes.last).to end_with(archive_hint)
    end

    it "should skip if the archive is not in Zenodo" do
      ["10.6084/m9.figshare.1", "10.1234/foozenodo.5", "https://notzenodo.org/records/5"].each do |archive|
        expect(@worker.zenodo_creators_for(archive, notes)).to be_nil
        expect(notes.last).to match(/is not a Zenodo DOI or URL/)
        expect(notes.last).to end_with(archive_hint)
      end
    end

    it "should skip Zenodo sandbox records" do
      expect(@worker.zenodo_creators_for("https://sandbox.zenodo.org/records/5", notes)).to be_nil
      expect(notes.last).to match(/is a Zenodo sandbox record/)
      expect(notes.last).to end_with(archive_hint)
    end

    it "should keep archive values on one line in notes" do
      @worker.zenodo_creators_for("not a doi\n\n@octocat", notes)
      expect(notes.last).to include("(`not a doi @octocat`)")
    end

    it "should accept Zenodo DOIs and record URLs" do
      body = { metadata: { creators: [{ name: "Doe, Jane" }] } }.to_json
      stub_request(:get, "https://zenodo.org/api/records/77").to_return(status: 200, body: body)
      ["10.5281/zenodo.77", "https://doi.org/10.5281/zenodo.77", "https://zenodo.org/records/77",
       "https://zenodo.org/record/77", "zenodo.org/records/77?preview=1", "https://zenodo.org/uploads/77"].each do |archive|
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
      expect(notes.last).to end_with(archive_hint)
    end

    it "should give up after too many redirects or a network error" do
      stub_request(:get, %r{https://zenodo.org/api/records/\d+}).to_return(status: 302, headers: { "Location" => "/api/records/1" })
      expect(@worker.zenodo_creators_for("10.5281/zenodo.1", notes)).to be_nil
      stub_request(:get, "https://zenodo.org/api/records/2").to_raise(Faraday::ConnectionFailed.new("down"))
      expect(@worker.zenodo_creators_for("10.5281/zenodo.2", notes)).to be_nil
      expect(notes.size).to eq(2)
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

      expect(client).to receive(:contributors).and_raise(Faraday::TimeoutError)
      expect(@worker.github_contributors_for("https://github.com/a/b", notes)).to be_nil
    end

    it "should keep the contributors if some profiles can't be looked up" do
      allow(client).to receive(:contributors).and_return([{ login: "jd", contributions: 9 }, { login: "x", contributions: 1 }])
      allow(@worker).to receive(:get_user).with("jd").and_return(double(name: "Jane Doe"))
      allow(@worker).to receive(:get_user).with("x").and_raise(Octokit::TooManyRequests)

      result = @worker.github_contributors_for("https://github.com/a/b", notes)
      expect(result).to eq([{ login: "jd", name: "Jane Doe", contributions: 9 }, { login: "x", name: "", contributions: 1 }])
      expect(notes).to eq(["I couldn't look up the GitHub profile of 1 contributor, so they were matched by username only."])
    end

    it "should only check the contributors with the most commits" do
      contributors = (1..55).map { |i| { login: "user#{i}", contributions: 100 - i } }
      allow(client).to receive(:contributors).and_return(contributors)
      allow(@worker).to receive(:get_user).and_return(nil)

      result = @worker.github_contributors_for("https://github.com/a/b", notes)
      expect(result.map { |c| c[:login] }).to eq((1..50).map { |i| "user#{i}" })
      expect(notes).to eq(["This repository has 55 contributors; only the 50 with the most commits were checked."])
    end
  end
end
