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
    end

    it "should classify as missing entries without DOI but with a candidate crossref entry" do
      missing_doi = BibTeX::Entry.new({title: "No DOI"})
      doi_checker = DOIChecker.new([missing_doi])

      expect(doi_checker).to receive(:crossref_lookup).with("No DOI").and_return("10.maybe/doi")

      doi_summary = doi_checker.check_dois
      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:missing].size).to eq(1)
      expect(doi_summary[:missing][0]).to eq("10.maybe/doi may be a valid DOI for title: No DOI")
    end

    it "should ignore entries no DOI and no crossref alternative" do
      missing_doi = BibTeX::Entry.new({title: "No DOI"})
      doi_checker = DOIChecker.new([missing_doi])

      expect(doi_checker).to receive(:crossref_lookup).with("No DOI").and_return(nil)

      doi_summary = doi_checker.check_dois

      expect(doi_summary[:ok]).to be_empty
      expect(doi_summary[:invalid]).to be_empty
      expect(doi_summary[:missing]).to be_empty
    end
  end

  describe "#validate_doi" do

    it "should invalidate empty doi strings" do
      expect(subject.validate_doi("")[:validity]).to eq(:invalid)
      expect(subject.validate_doi(nil)[:validity]).to eq(:invalid)
    end

    it "should invalidate urls" do
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
      doi = "10.1#{}234/jou'(r)nal_567\"89"
      doi_url = "https://doi.org/10.1234/journal_56789"
      expect(Faraday).to receive(:head).with(doi_url).and_return(OpenStruct.new(status: 400))
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

    it "should return nothing if crossref errors" do
      expect(Serrano).to receive(:works).and_raise Serrano::InternalServerError
      expect(subject.crossref_lookup("Title")).to be_nil
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