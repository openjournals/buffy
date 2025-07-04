require_relative "./spec_helper.rb"

describe DOIChecker do
  subject do
    DOIChecker.new
  end

  describe "#check_dois" do
    it "should be empty if no entries" do
      doi_summary = DOIChecker.new.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:missing]).to be_empty
      expect(doi_summary[:skip]).to be_empty
    end

    it "should classify as invalid entries with invalid DOI" do
      invalid_doi = BibTeX::Entry.new({title: "Wrong DOI", doi: "10.inva/lid"})
      doi_checker = DOIChecker.new([invalid_doi])

      validity = { validity: :invalid, msg: "10.inva/lid is INVALID" }
      expect(doi_checker).to receive(:validate_doi).with("10.inva/lid").and_return(validity)

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid].size).to eq(1)
      expect(doi_summary[:invalid].first).to eq(validity[:msg])
      expect(doi_summary[:missing]).to be_empty
      expect(doi_summary[:skip]).to be_empty
    end

    it "should classify as ok entries with valid DOI" do
      valid_doi = BibTeX::Entry.new({title: "Good DOI", doi: "10.1234/567"})
      doi_checker = DOIChecker.new([valid_doi])

      validity = { validity: :ok, msg: "10.1234/567 is OK" }
      expect(doi_checker).to receive(:validate_doi).with("10.1234/567").and_return(validity)

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok].size).to eq(1)
      expect(doi_summary[:ok].first).to eq(validity[:msg])
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:missing]).to be_empty
      expect(doi_summary[:skip]).to be_empty
    end

    it "should classify as missing entries without DOI but with a candidate crossref entry" do
      missing_doi = BibTeX::Entry.new({title: "No DOI"})
      doi_checker = DOIChecker.new([missing_doi])

      expect(doi_checker).to receive(:crossref_lookup).with("No DOI").and_return("10.maybe/doi")

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:skip]).to be_empty
      expect(doi_summary[:missing].size).to eq(1)
      expect(doi_summary[:missing][0]).to eq("10.maybe/doi may be a valid DOI for title: No DOI")
    end

    it "should create error message for missing entries when Crossref errors" do
      missing_doi = BibTeX::Entry.new({title: "No DOI"})
      doi_checker = DOIChecker.new([missing_doi])

      expect(doi_checker).to receive(:crossref_lookup).with("No DOI").and_return("CROSSREF-ERROR")

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:skip]).to be_empty
      expect(doi_summary[:missing].size).to eq(1)
      expect(doi_summary[:missing][0]).to eq('Errored finding suggestions for "No DOI", please try later')
    end

    it "should truncate missing entry title in error messages" do
      title = "1111111111222222222233333333334444444444555555555566666666667777777777"
      expected_title = "11111111112222222222333333333344444444445555555555..."
      missing_doi = BibTeX::Entry.new({title: title})
      doi_checker = DOIChecker.new([missing_doi])

      expect(doi_checker).to receive(:crossref_lookup).with(title).and_return("CROSSREF-ERROR")

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:skip]).to be_empty
      expect(doi_summary[:missing].size).to eq(1)
      expect(doi_summary[:missing][0]).to eq("Errored finding suggestions for \"#{expected_title}\", please try later")
    end

    it "should report entries with no DOI and no crossref alternative as missing DOIs" do
      title = "No DOI"
      missing_doi = BibTeX::Entry.new({title: title})
      doi_checker = DOIChecker.new([missing_doi])

      expect(doi_checker).to receive(:crossref_lookup).with("No DOI").and_return(nil)

      doi_summary = doi_checker.check_dois

      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:missing]).to be_empty
      expect(doi_summary[:skip].size).to eq(1)
      expect(doi_summary[:skip][0]).to eq("No DOI given, and none found for title: #{title}")
    end

    it "should report entries with no DOI or title as missing both" do
      entry = BibTeX::Entry.new(journal: "A Well Respected Journal")
      doi_checker = DOIChecker.new([entry])

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:skip]).to be_empty
      expect(doi_summary[:missing][0]).to eq("Entry without DOI or title found")
    end
  end

  describe "#handle_special_case" do
    it "should treat DOIs with a 10.5555 prefix as invalid" do
      entry = BibTeX::Entry.new(doi: "10.5555/xxxxxxx.yyyyyyyyy")
      validity = subject.handle_special_case(entry)
      expect(validity[:validity]).to eq(:invalid)
      expect(validity[:msg]).to include("replace with https://dl.acm.org/doi")
    end

    it "should treat URLs with a 10.5555 prefix as a skip" do
      entry = BibTeX::Entry.new(url: "https://dl.acm.org/doi/10.5555/2827719.2827740")
      validity = subject.handle_special_case(entry)
      expect(validity[:validity]).to eq(:skip)
      expect(validity[:msg]).to eq("https://dl.acm.org/doi/10.5555/2827719.2827740 - non-DOI with 10.5555 correctly placed in the url field, editor should ensure this resolves")
    end

    it "should handle special cases separately from normal DOI checking" do
      entry = BibTeX::Entry.new(doi: "10.5555/xxxxxxx.yyyyyyyyy")
      doi_checker = DOIChecker.new([entry])

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:missing]).to be_empty
      expect(doi_summary[:skip]).to be_empty
      expect(doi_summary[:invalid][0]).to include("is INVALID - 10.5555 is not a DOI prefix, but rather a handle prefix. Please replace the {doi} field with a {url} field that resolves in a browser.")
    end
  end

  describe "#validate_doi" do

    it "should invalidate empty doi strings" do
      expect(subject.validate_doi("")[:validity]).to eq(:invalid)
      expect(subject.validate_doi(nil)[:validity]).to eq(:invalid)
    end

    it "should invalidate urls" do
      expect(subject.validate_doi("doi.org/10.3333/12345")[:validity]).to eq(:invalid)
      expect(subject.validate_doi("http://doi.org/10.3333/12345")[:validity]).to eq(:invalid)
      expect(subject.validate_doi("https://github.com/10.3333/12345")[:validity]).to eq(:invalid)
    end

    it "should validate doi.org ok responses" do
      doi = "10.21105/joss.02670"
      doi_url = "https://doi.org/#{doi}"
      expect(Faraday).to receive(:head).with(doi_url).and_return(OpenStruct.new(status: 301))
      expect(subject.validate_doi(doi)[:validity]).to eq(:ok)
      expect(Faraday).to receive(:head).with(doi_url).and_return(OpenStruct.new(status: 302))
      expect(subject.validate_doi(doi)[:validity]).to eq(:ok)
    end

    it "should invalidate doi.org not found responses" do
      doi = "10.1234/56789"
      doi_url = "https://doi.org/#{doi}"
      expect(Faraday).to receive(:head).with(doi_url).and_return(OpenStruct.new(status: 400))
      expect(subject.validate_doi(doi)[:validity]).to eq(:invalid)
    end

    it "should invalidate doi if the doi.org call raises a exception" do
      expect(Faraday).to receive(:head).and_raise URI::InvalidURIError
      expect(subject.validate_doi("doi")[:validity]).to eq(:invalid)
      expect(Faraday).to receive(:head).and_raise Faraday::ConnectionFailed.new("timeout")
      expect(subject.validate_doi("doi")[:validity]).to eq(:invalid)
    end

    it "should sanitize doi strings" do
      doi = "10.1#}{234/jou'rnal:_5(67)\"-89"
      doi_url = "https://doi.org/10.1234/journal:_5(67)-89"
      expect(Faraday).to receive(:head).with(doi_url).and_return(OpenStruct.new(status: 400))
      subject.validate_doi(doi)
    end

    it "should allow all DOI valid characters and query escape special characters" do
      doi = "10.1002/(sici)1096-9136(199606)13:6<536::aid-dia110>3.0.co;2-j"
      doi_url = "https://doi.org/10.1002/(sici)1096-9136(199606)13:6%3C536::aid-dia110%3E3.0.co;2-j"
      expect(Faraday).to receive(:head).with(doi_url).and_return(OpenStruct.new(status: 301))
      subject.validate_doi(doi)

      doi = "10.1577/1548-8446(2006)31[590:TCFIE]2.0.CO;2"
      doi_url = "https://doi.org/10.1577/1548-8446(2006)31%5B590:TCFIE%5D2.0.CO;2"
      expect(Faraday).to receive(:head).with(doi_url).and_return(OpenStruct.new(status: 301))
      subject.validate_doi(doi)
    end
  end

  describe "#crossref_lookup" do
    it "should return DOI suggestion if good crossref candidate exists" do
      title = "Nampo, a library for numerical calculations"
      similar_title = "Numpy, a library for numerical calculations"
      crossref_reply = {'message' =>  {'items' => [{'title' => [similar_title], 'DOI' => '10.123/456'}]}}
      expect(Serrano).to receive(:works).with({query: title}).and_return(crossref_reply)
      expect(subject.crossref_lookup(title)).to eq("10.123/456")
    end

    it "should return nothing if there's not a crossref candidate" do
      crossref_reply = {'message' =>  {'items' => []}}
      expect(Serrano).to receive(:works).with({query: "Title"}).and_return(crossref_reply)
      expect(subject.crossref_lookup("Title")).to be_nil
    end

    it "should return nothing if there's not a good enough crossref candidate" do
      title = "Numpy, a library for numerical calculations"
      crossref_reply = {'message' =>  {'items' => [{'title' => ['Num not similar'], 'DOI' => '10.123/456'}]}}
      expect(Serrano).to receive(:works).with({query: title}).and_return(crossref_reply)
      expect(subject.crossref_lookup(title)).to be_nil
    end

    it "should return CROSSREF-ERROR if crossref errors" do
      expect(Serrano).to receive(:works).and_raise Serrano::InternalServerError
      expect(subject.crossref_lookup("Title")).to eq("CROSSREF-ERROR")
    end
  end

  describe "#levenshtein_distance" do

    it "should measure the difference between strings" do
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

end
