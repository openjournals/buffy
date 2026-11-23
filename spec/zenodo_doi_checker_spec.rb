require_relative "./spec_helper.rb"

describe ZenodoDoiChecker do
  let(:api) { "https://zenodo.org/api/records" }

  def record(id:, doi:, conceptrecid:, conceptdoi:, version: "1.0", is_last: true)
    metadata = { version: version }
    metadata[:relations] = { version: [{ index: 0, is_last: is_last }] } unless is_last.nil?
    { id: id, doi: doi, conceptrecid: conceptrecid, conceptdoi: conceptdoi, metadata: metadata }.to_json
  end

  def stub_record(id, body, status: 200)
    stub_request(:get, "#{api}/#{id}").to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  def stub_redirect(from, to, status: 302)
    stub_request(:get, "#{api}/#{from}").to_return(status: status, headers: { "Location" => "#{api}/#{to}" })
  end

  let(:latest_version) do
    record(id: 200, doi: "10.5281/zenodo.200", conceptrecid: "100", conceptdoi: "10.5281/zenodo.100", version: "v2.0")
  end

  describe "version DOIs" do
    it "recognizes the DOI of a record's version, with its concept DOI" do
      stub_record(200, latest_version)
      expect(described_class.new("10.5281/zenodo.200").check).to eq(
        type: :version, doi: "10.5281/zenodo.200", concept_doi: "10.5281/zenodo.100", version: "v2.0", latest: true
      )
    end

    it "says when there's a newer version" do
      stub_record(150, record(id: 150, doi: "10.5281/zenodo.150", conceptrecid: "100", conceptdoi: "10.5281/zenodo.100", is_last: false))
      expect(described_class.new("10.5281/zenodo.150").check).to include(type: :version, latest: false)
    end

    it "doesn't say whether it's the latest version when Zenodo doesn't" do
      stub_record(150, record(id: 150, doi: "10.5281/zenodo.150", conceptrecid: "100", conceptdoi: "10.5281/zenodo.100", is_last: nil))
      expect(described_class.new("10.5281/zenodo.150").check).to include(type: :version, latest: nil)
    end

    it "handles a version with no concept DOI" do
      stub_record(150, record(id: 150, doi: "10.5281/zenodo.150", conceptrecid: nil, conceptdoi: nil))
      expect(described_class.new("10.5281/zenodo.150").check).to include(type: :version, concept_doi: nil)
    end
  end

  describe "concept DOIs" do
    it "recognizes a concept DOI from Zenodo's redirect to the latest version" do
      stub_redirect(100, 200)
      stub_record(200, latest_version)
      expect(described_class.new("10.5281/zenodo.100").check).to eq(
        type: :concept, doi: "10.5281/zenodo.100", latest_doi: "10.5281/zenodo.200", version: "v2.0"
      )
    end

    it "follows a permanent redirect too" do
      stub_redirect(100, 200, status: 301)
      stub_record(200, latest_version)
      expect(described_class.new("10.5281/zenodo.100").check).to include(type: :concept)
    end

    it "recognizes a concept DOI if Zenodo answers with the record directly" do
      stub_record(100, latest_version)
      expect(described_class.new("10.5281/zenodo.100").check).to include(type: :concept, latest_doi: "10.5281/zenodo.200")
    end

    it "isn't fooled by a redirect to a record of another concept" do
      stub_redirect(100, 300)
      stub_record(300, record(id: 300, doi: "10.5281/zenodo.300", conceptrecid: "299", conceptdoi: "10.5281/zenodo.299"))
      expect(described_class.new("10.5281/zenodo.100").check[:type]).to eq(:not_found)
    end

    it "doesn't count a concept that has no registered DOI" do
      stub_redirect(100, 200)
      stub_record(200, record(id: 200, doi: "10.1234/imported", conceptrecid: "100", conceptdoi: nil))
      expect(described_class.new("10.5281/zenodo.100").check[:type]).to eq(:not_found)
    end

    it "reports an error if the latest version can't be fetched" do
      stub_redirect(100, 200)
      stub_record(200, "", status: 500)
      expect(described_class.new("10.5281/zenodo.100").check[:type]).to eq(:error)
    end
  end

  describe "ways of writing the DOI" do
    before { stub_record(200, latest_version) }

    ["10.5281/zenodo.200", "10.5281/ZENODO.200", "doi:10.5281/zenodo.200", "DOI: 10.5281/zenodo.200",
     "https://doi.org/10.5281/zenodo.200", "http://dx.doi.org/10.5281/zenodo.200", " 10.5281/zenodo.200. "].each do |value|
      it "accepts #{value.inspect}" do
        expect(described_class.new(value).check[:type]).to eq(:version)
      end
    end
  end

  describe "DOIs that can't be classified" do
    it "rejects DOIs that aren't Zenodo DOIs without calling Zenodo" do
      expect(described_class.new("10.21105/joss.01234").check).to eq(type: :not_zenodo, doi: "10.21105/joss.01234")
      expect(described_class.new("10.5281/zenodo.12a").check[:type]).to eq(:not_zenodo)
      expect(described_class.new("").check[:type]).to eq(:not_zenodo)
      expect(a_request(:get, /zenodo/)).to_not have_been_made
    end

    it "reports records that don't exist" do
      stub_record(999, { status: 404 }.to_json, status: 404)
      expect(described_class.new("10.5281/zenodo.999").check[:type]).to eq(:not_found)
    end

    it "reports deleted records as not found" do
      stub_record(999, { status: 410 }.to_json, status: 410)
      expect(described_class.new("10.5281/zenodo.999").check[:type]).to eq(:not_found)
    end

    it "reports a record imported with a DOI from somewhere else as not found" do
      stub_record(200, record(id: 200, doi: "10.1234/imported", conceptrecid: "100", conceptdoi: nil))
      expect(described_class.new("10.5281/zenodo.200").check[:type]).to eq(:not_found)
    end

    it "reports an error on unexpected responses" do
      stub_record(200, "", status: 503)
      expect(described_class.new("10.5281/zenodo.200").check[:type]).to eq(:error)
    end

    it "reports an error on invalid JSON" do
      stub_record(200, "<html>")
      expect(described_class.new("10.5281/zenodo.200").check[:type]).to eq(:error)
    end

    it "reports an error if Zenodo can't be reached" do
      stub_request(:get, "#{api}/200").to_timeout
      expect(described_class.new("10.5281/zenodo.200").check[:type]).to eq(:error)
    end
  end
end
