require_relative "./spec_helper.rb"

describe AuthorsChecker do

  subject { described_class.new }

  describe "#compare" do
    it "is :exact for the same name, also in 'Last, First' format" do
      expect(subject.compare({ name: "Jane Doe" }, { name: "Jane Doe" })).to eq(:exact)
      expect(subject.compare({ name: "Guillaume J. Laurent" }, { name: "Laurent, Guillaume J." })).to eq(:exact)
      expect(subject.compare({ name: "José Vergara Álvarez" }, { name: "Vergara Álvarez, José" })).to eq(:exact)
    end

    it "is :same when only case, accents or punctuation differ" do
      expect(subject.compare({ name: "Antoine N. André" }, { name: "ANDRE, Antoine N." })).to eq(:same)
      expect(subject.compare({ name: "Jean-Luc Picard" }, { name: "Jean Luc Picard" })).to eq(:same)
    end

    it "is :close for the same ORCID with a different name" do
      author = { name: "Jane Doe", orcid: "0000-0001-2345-6789" }
      other = { name: "J. Smith", orcid: "https://orcid.org/0000-0001-2345-6789" }
      expect(subject.compare(author, other)).to eq(:close)
    end

    it "is :close for missing middle names or initials" do
      expect(subject.compare({ name: "John A. Smith" }, { name: "John Smith" })).to eq(:close)
      expect(subject.compare({ name: "John Smith" }, { name: "J. Smith" })).to eq(:close)
      expect(subject.compare({ name: "Juan Pablo Aguilar Calle" }, { name: "Juan Pablo Aguilar" })).to eq(:close)
    end

    it "is :close for a one-letter typo" do
      expect(subject.compare({ name: "Jonathan Smith" }, { name: "Johnathan Smith" })).to eq(:close)
    end

    it "is :close for a GitHub username built from the author's name" do
      expect(subject.compare({ name: "Raghotham Murthy" }, { login: "raghotham", name: "" })).to eq(:close)
      expect(subject.compare({ name: "Varsha Prasad Narsing" }, { login: "varshaprasad96", name: "Varsha" })).to eq(:close)
      expect(subject.compare({ name: "John Smith" }, { login: "jsmith", name: "" })).to eq(:close)
    end

    it "doesn't use the username when the profile name belongs to someone else" do
      expect(subject.compare({ name: "David Smith" }, { login: "david", name: "David Jones" })).to be_nil
      expect(subject.compare({ name: "Maria Garcia" }, { login: "maria-k", name: "Maria Kowalski" })).to be_nil
      expect(subject.compare({ name: "John Smith" }, { login: "jsmith", name: "Jane Roe" })).to be_nil
    end

    it "doesn't match usernames on very short names" do
      expect(subject.compare({ name: "An Li" }, { login: "danielinglis", name: "" })).to be_nil
      expect(subject.compare({ name: "Yu Ma" }, { login: "yumamoto", name: "" })).to be_nil
      expect(subject.compare({ name: "Xu Li" }, { login: "alexulin", name: "" })).to be_nil
    end

    it "is :close for the same name with a different ORCID" do
      author = { name: "Jane Doe", orcid: "0000-0001-2345-6789" }
      expect(subject.compare(author, { name: "Doe, Jane", orcid: "0000-0009-8765-4321" })).to eq(:close)
      expect(subject.compare(author, { name: "Doe, Jane", orcid: "https://orcid.org/0000-0001-2345-6789" })).to eq(:exact)
      expect(subject.compare(author, { name: "Doe, Jane", orcid: "" })).to eq(:exact)
    end

    it "is nil for different people" do
      expect(subject.compare({ name: "Tanya Sah" }, { name: "Tanmay Sah" })).to be_nil
      expect(subject.compare({ name: "Jane Doe" }, { name: "John Smith" })).to be_nil
      expect(subject.compare({ name: "Jane Doe" }, { login: "jane", name: "" })).to be_nil
      expect(subject.compare({ name: "" }, { name: "" })).to be_nil
    end
  end

  describe "#check" do
    let(:paper_authors) { [{ name: "Jane Doe" }, { name: "Antoine André" }, { name: "Tanya Sah" }, { name: "Tanmay Sah" }] }
    let(:zenodo) { [{ name: "Doe, Jane" }, { name: "ANDRE, Antoine" }, { name: "Sah, Tanmay" }, { name: "Extra, Person" }] }
    let(:github) do
      [{ login: "janedoe", name: "Jane Doe", contributions: 10 },
       { login: "jane-alt", name: "Jane Doe", contributions: 2 },
       { login: "tradertanmay", name: "Tanmay Sah", contributions: 5 },
       { login: "reviewer1", name: "Rev Iewer", contributions: 1 },
       { login: "someone", name: "Some One", contributions: 3 }]
    end

    let(:report) do
      described_class.new(paper_authors: paper_authors, zenodo_creators: zenodo,
                          github_contributors: github, ignored_logins: ["@Reviewer1"]).check
    end

    it "matches each paper author with the Zenodo creators" do
      statuses = report[:authors].map { |r| r[:zenodo]&.dig(:status) }
      expect(statuses).to eq([:exact, :same, nil, :exact])
    end

    it "matches each paper author with the GitHub contributors" do
      logins = report[:authors].map { |r| r[:github]&.dig(:person, :login) }
      expect(logins).to eq(["janedoe", nil, nil, "tradertanmay"])
    end

    it "lists Zenodo creators that are not paper authors" do
      expect(report[:zenodo_only]).to eq([{ name: "Extra, Person" }])
    end

    it "lists GitHub contributors that are not paper authors, excluding ignored users and extra accounts" do
      expect(report[:github_only].map { |c| c[:login] }).to eq(["someone"])
    end

    it "lists probable matches that weren't chosen, so nobody disappears" do
      authors = [{ name: "Wei Li" }, { name: "Anna Schmidt" }, { name: "Jane Doe" }]
      github = [{ login: "weili", name: "Wei Li", contributions: 10 },
                { login: "liwei-chen", name: "Liwei Chen", contributions: 25 },
                { login: "aschmidt", name: "", contributions: 3 }]
      zenodo = [{ name: "Doe, Jane" }, { name: "Doe, J." }]
      report = described_class.new(paper_authors: authors, zenodo_creators: zenodo, github_contributors: github).check

      expect(report[:authors].map { |r| r[:github]&.dig(:person, :login) }).to eq(["weili", "aschmidt", nil])
      expect(report[:github_only].map { |c| c[:login] }).to eq(["liwei-chen"])
      expect(report[:zenodo_only]).to eq([{ name: "Doe, J." }])
    end

    it "includes both ORCIDs in a match when they differ" do
      authors = [{ name: "Jane Doe", orcid: "0000-0001-2345-6789" }, { name: "John Smith", orcid: "0000-0002-0000-0001" }]
      zenodo = [{ name: "Doe, Jane", orcid: "0000-0009-8765-4321" }, { name: "Smith, John", orcid: "0000-0002-0000-0001" }]
      report = described_class.new(paper_authors: authors, zenodo_creators: zenodo).check

      expect(report[:authors].map { |r| [r[:zenodo][:status], r[:zenodo][:orcids]] }).to eq([[:close, ["0000-0001-2345-6789", "0000-0009-8765-4321"]], [:exact, nil]])
      expect(report[:zenodo_only]).to eq([])
    end

    it "uses nil for sources that were not checked" do
      report = described_class.new(paper_authors: paper_authors).check
      expect(report[:zenodo_only]).to be_nil
      expect(report[:github_only]).to be_nil
      expect(report[:authors].first[:zenodo]).to be_nil
    end
  end
end
