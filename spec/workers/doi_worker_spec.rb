require_relative "../spec_helper.rb"

describe DOIWorker do

  describe "perform" do
    before do
      @worker = described_class.new
      disable_github_calls_for(@worker)
    end

    it "should do nothing if error checking out the repo branch" do
      expect(@worker).to receive(:setup_local_repo).and_return(false)
      expect(PaperFile).to_not receive(:new)
      @worker.perform({}, 'url', 'main')
    end

    it "should reply error message if reading bibtex file fails" do
      expect(@worker).to receive(:setup_local_repo).and_return(true)
      paper_file = PaperFile.new
      paper_file.bibtex_error = "Bibliography file not found"
      expect(PaperFile).to receive(:find).and_return(paper_file)
      expected_response = "Checking the BibTeX entries failed with the following error: \n```\nBibliography file not found\n```"
      expect(@worker).to receive(:respond).with(expected_response)
      @worker.perform({}, 'url', 'main')
    end

    it "should respond with the doi_checks erb template" do
      expect(@worker).to receive(:setup_local_repo).and_return(true)

      paper_file = PaperFile.new("path/to/paper.md")
      expect(PaperFile).to receive(:find).and_return(paper_file)
      expect(paper_file).to receive(:bibtex_entries).and_return(["bibtex_entries"])

      doi_checker = DOIChecker.new(["bibtex_entries"])
      expected_doi_summary = {ok: ["10.1234/567"], invalid: ["wrong-doi"], missing: []}
      expect(DOIChecker).to receive(:new).with(["bibtex_entries"]).and_return(doi_checker)
      expect(doi_checker).to receive(:check_dois).and_return(expected_doi_summary)

      expect(@worker).to receive(:respond_template).once.with(:doi_checks, doi_summary: expected_doi_summary)
      @worker.perform({}, 'url', 'main')
    end
  end

end
