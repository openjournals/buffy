require_relative "./spec_helper.rb"

describe AuthorsChecker do

  subject { described_class.new }

  def compare(author_name, other, author_orcid: nil)
    author = { name: author_name }
    author[:orcid] = author_orcid if author_orcid
    other = { name: other } if other.is_a?(String)
    subject.compare(author, other)
  end

  describe "#display_name" do
    it "keeps a 'First Last' name" do
      expect(subject.display_name("Jane Doe")).to eq("Jane Doe")
    end

    it "turns 'Last, First' into 'First Last'" do
      expect(subject.display_name("Doe, Jane")).to eq("Jane Doe")
    end

    it "strips spaces around the parts of 'Last, First'" do
      expect(subject.display_name("  Doe ,   Jane  ")).to eq("Jane Doe")
    end

    it "doesn't reorder names with more than one comma" do
      expect(subject.display_name("Doe, Jane, Jr.")).to eq("Doe, Jane, Jr.")
    end

    it "collapses whitespace" do
      expect(subject.display_name("Jane   Q.\tDoe")).to eq("Jane Q. Doe")
    end

    it "handles a missing first or last part" do
      expect(subject.display_name("Doe,")).to eq("Doe")
      expect(subject.display_name(",Jane")).to eq("Jane")
    end

    it "is empty for nil or blank names" do
      expect(subject.display_name(nil)).to eq("")
      expect(subject.display_name("   ")).to eq("")
    end
  end

  describe "#normalize_name" do
    it "lowercases" do
      expect(subject.normalize_name("JANE DOE")).to eq("jane doe")
    end

    it "removes accents" do
      expect(subject.normalize_name("José Álvarez Zoë Ünal")).to eq("jose alvarez zoe unal")
    end

    it "keeps letters without a decomposed form" do
      expect(subject.normalize_name("Øyvind Hansen")).to eq("øyvind hansen")
    end

    it "keeps non-Latin scripts" do
      expect(subject.normalize_name("李 小龍")).to eq("李 小龍")
    end

    it "turns hyphens, underscores and dots into spaces" do
      expect(subject.normalize_name("Jean-Luc Mary_Ann J.R. Smith")).to eq("jean luc mary ann j r smith")
      expect(subject.normalize_name("Jean‐Luc")).to eq("jean luc")
    end

    it "removes other punctuation" do
      expect(subject.normalize_name("Conan O'Brien (PhD)")).to eq("conan obrien phd")
    end

    it "keeps digits" do
      expect(subject.normalize_name("R2 D2")).to eq("r2 d2")
    end

    it "reorders 'Last, First'" do
      expect(subject.normalize_name("ANDRE, Antoine N.")).to eq("antoine n andre")
    end

    it "is empty for nil" do
      expect(subject.normalize_name(nil)).to eq("")
    end
  end

  describe "#compare" do
    context "with the same name" do
      it "is :exact for identical names" do
        expect(compare("Jane Doe", "Jane Doe")).to eq(:exact)
      end

      it "is :exact for 'Last, First'" do
        expect(compare("Guillaume J. Laurent", "Laurent, Guillaume J.")).to eq(:exact)
        expect(compare("José Vergara Álvarez", "Vergara Álvarez, José")).to eq(:exact)
      end

      it "is :exact when only spacing differs" do
        expect(compare("Jane  Doe ", "Jane Doe")).to eq(:exact)
      end

      it "is :exact when only periods after initials differ" do
        expect(compare("Simon J. Greenhill", "Simon J Greenhill")).to eq(:exact)
        expect(compare("Greenhill, Simon J", "Simon J. Greenhill")).to eq(:exact)
        expect(compare("J.R.R. Tolkien", "J R R Tolkien")).to eq(:exact)
      end

      it "keeps periods that don't follow an initial" do
        expect(compare("Martin Luther King Jr.", "Martin Luther King Jr")).to eq(:same)
      end

      it "is :same when only case differs" do
        expect(compare("jane doe", "Jane Doe")).to eq(:same)
      end

      it "is :same when only accents differ" do
        expect(compare("Antoine André", "Antoine Andre")).to eq(:same)
      end

      it "is :same when accents and case differ in 'Last, First'" do
        expect(compare("Antoine N. André", "ANDRE, Antoine N.")).to eq(:same)
      end

      it "is :same when only punctuation differs" do
        expect(compare("Jean-Luc Picard", "Jean Luc Picard")).to eq(:same)
      end

      it "is :same when the names are in a different order without a comma" do
        expect(compare("Doe Jane", "Jane Doe")).to eq(:same)
      end
    end

    context "with ORCIDs" do
      let(:orcid) { "0000-0001-2345-6789" }

      it "is :close for the same name with a different ORCID" do
        expect(compare("Jane Doe", { name: "Doe, Jane", orcid: "0000-0009-8765-4321" }, author_orcid: orcid)).to eq(:close)
      end

      it "is :close for the same name ignoring case with a different ORCID" do
        expect(compare("Jane Doe", { name: "DOE, JANE", orcid: "0000-0009-8765-4321" }, author_orcid: orcid)).to eq(:close)
      end

      it "stays :exact or :same with the same ORCID, in any format" do
        expect(compare("Jane Doe", { name: "Doe, Jane", orcid: "https://orcid.org/#{orcid}" }, author_orcid: orcid)).to eq(:exact)
        expect(compare("Jane Doe", { name: "DOE, JANE", orcid: orcid }, author_orcid: orcid)).to eq(:same)
      end

      it "treats a lowercase x checksum like an uppercase one" do
        expect(compare("Jane Doe", { name: "Jane Doe", orcid: "0000-0002-1825-009x" }, author_orcid: "0000-0002-1825-009X")).to eq(:exact)
      end

      it "stays :exact if only one of them has an ORCID" do
        expect(compare("Jane Doe", { name: "Jane Doe", orcid: "" }, author_orcid: orcid)).to eq(:exact)
        expect(compare("Jane Doe", { name: "Jane Doe", orcid: orcid })).to eq(:exact)
      end

      it "ignores values that aren't ORCIDs" do
        expect(compare("Jane Doe", { name: "Jane Doe", orcid: "n/a" }, author_orcid: orcid)).to eq(:exact)
      end

      it "is :close for different names with the same ORCID" do
        expect(compare("Jane Doe", { name: "Zed Quux", orcid: orcid }, author_orcid: orcid)).to eq(:close)
      end

      it "doesn't match different names when only the other person has an ORCID" do
        expect(compare("Jane Doe", { name: "Zed Quux", orcid: orcid })).to be_nil
      end
    end

    context "with similar names" do
      it "is :close for an initial instead of a first name, either way" do
        expect(compare("John Smith", "J. Smith")).to eq(:close)
        expect(compare("J. Smith", "John Smith")).to eq(:close)
      end

      it "is :close for a missing or extra middle name" do
        expect(compare("John A. Smith", "John Smith")).to eq(:close)
        expect(compare("John Smith", "John Adam Smith")).to eq(:close)
      end

      it "is nil for a different first name with the same last name" do
        expect(compare("John Smith", "Jane Smith")).to be_nil
      end

      it "is nil for different initials" do
        expect(compare("K. Smith", "J. Smith")).to be_nil
      end

      it "doesn't match a single name with a longer one" do
        expect(compare("Madonna", "Madonna Ciccone")).to be_nil
      end

      it "is :close when all names of one are part of the other, either way" do
        expect(compare("Juan Pablo Aguilar Calle", "Juan Pablo Aguilar")).to eq(:close)
        expect(compare("Juan Pablo Aguilar", "Juan Pablo Aguilar Calle")).to eq(:close)
        expect(compare("Aguilar Juan Pablo", "Juan Pablo Aguilar Calle")).to eq(:close)
      end

      it "is :close for a short form of a name, ignoring case" do
        expect(compare("Elijah Knaap", "eli knaap")).to eq(:close)
        expect(compare("Daniel Arribas-Bel", "Dani Arribas-Bel")).to eq(:close)
        expect(compare("Dani Arribas-Bel", "Daniel Arribas-Bel")).to eq(:close)
      end

      it "matches each name with any other name, in any order" do
        expect(compare("Elijah Knaap", "Knaap, Eli")).to eq(:close)
        expect(compare("Knaap Elijah", "Eli Knaap")).to eq(:close)
        expect(compare("Elijah J. Knaap", "Eli Knaap")).to eq(:close)
      end

      it "doesn't count short forms of fewer than 3 letters" do
        expect(compare("Johnny Smith", "Jo Smith")).to be_nil
      end

      it "doesn't match a short form that isn't the start of the name" do
        expect(compare("Elijah Knaap", "Lija Knaap")).to be_nil
      end

      it "is :close for a one-letter typo in a long name" do
        expect(compare("Jonathan Smith", "Johnathan Smith")).to eq(:close)
      end

      it "is nil for two different letters" do
        expect(compare("Tanya Sah", "Tanmay Sah")).to be_nil
        expect(compare("Jonathan Smith", "Jonathon Smyth")).to be_nil
      end

      it "only counts one-letter typos in names longer than 8 characters" do
        expect(compare("Anna Sahl", "Anna Sahk")).to eq(:close)
        expect(compare("Ann Sahl", "Ann Sahk")).to be_nil
      end
    end

    context "with GitHub usernames" do
      it "is :close for a username built from the name when the profile has no name" do
        expect(compare("Raghotham Murthy", { login: "raghotham", name: "" })).to eq(:close)
        expect(compare("John Smith", { login: "jsmith", name: "" })).to eq(:close)
      end

      it "is :close when the profile has just one of the author's names" do
        expect(compare("Varsha Prasad Narsing", { login: "varshaprasad96", name: "Varsha" })).to eq(:close)
      end

      it "doesn't use the username when the profile has one name that isn't the author's" do
        expect(compare("John Smith", { login: "johnsmith", name: "Bob" })).to be_nil
      end

      it "doesn't use the username when the profile name belongs to someone else" do
        expect(compare("David Smith", { login: "david", name: "David Jones" })).to be_nil
        expect(compare("Maria Garcia", { login: "maria-k", name: "Maria Kowalski" })).to be_nil
        expect(compare("John Smith", { login: "jsmith", name: "Jane Roe" })).to be_nil
      end

      it "doesn't match usernames on very short names" do
        expect(compare("An Li", { login: "danielinglis", name: "" })).to be_nil
        expect(compare("Yu Ma", { login: "yumamoto", name: "" })).to be_nil
        expect(compare("Xu Li", { login: "alexulin", name: "" })).to be_nil
      end

      it "doesn't match a username that doesn't look like the name" do
        expect(compare("Jane Doe", { login: "jane", name: "" })).to be_nil
      end

      it "doesn't look at usernames for people without one (Zenodo)" do
        expect(compare("John Smith", { name: "" })).to be_nil
      end
    end

    context "with empty names" do
      it "is nil when both names are empty" do
        expect(compare("", "")).to be_nil
      end

      it "is nil when one of the names is empty" do
        expect(compare("", "Jane Doe")).to be_nil
        expect(compare("Jane Doe", "")).to be_nil
      end

      it "is nil for nil names" do
        expect(subject.compare({}, { name: "Jane Doe" })).to be_nil
      end
    end
  end

  describe "private matching rules" do
    describe "#token_match?" do
      it "matches equal names" do
        expect(subject.send(:token_match?, "john", "john")).to be true
      end

      it "matches an initial with a name, either way" do
        expect(subject.send(:token_match?, "j", "john")).to be true
        expect(subject.send(:token_match?, "john", "j")).to be true
      end

      it "doesn't match different initials" do
        expect(subject.send(:token_match?, "j", "k")).to be false
      end

      it "doesn't treat two letters as an initial or a short form" do
        expect(subject.send(:token_match?, "jo", "john")).to be false
      end

      it "matches a short form of 3 or more letters with the longer name, either way" do
        expect(subject.send(:token_match?, "eli", "elijah")).to be true
        expect(subject.send(:token_match?, "elijah", "eli")).to be true
        expect(subject.send(:token_match?, "john", "johnny")).to be true
      end

      it "doesn't match names that only share their first letters" do
        expect(subject.send(:token_match?, "tanya", "tanmay")).to be false
      end
    end

    describe "#all_tokens_matched?" do
      it "matches every name with a different name, in any order" do
        expect(subject.send(:all_tokens_matched?, %w[knaap eli], %w[elijah knaap])).to be true
      end

      it "doesn't use one name twice" do
        expect(subject.send(:all_tokens_matched?, %w[eli elijah], %w[elijah knaap])).to be false
      end

      it "pairs equal names before short forms" do
        expect(subject.send(:all_tokens_matched?, %w[dan daniel], %w[daniel danielle])).to be true
      end
    end

    describe "#login_usable?" do
      it "is true when the profile has no name" do
        expect(subject.send(:login_usable?, [], ["john", "smith"])).to be true
      end

      it "is true when the profile has one of the author's names" do
        expect(subject.send(:login_usable?, ["varsha"], ["varsha", "prasad"])).to be true
      end

      it "is false when the profile has one name that isn't the author's" do
        expect(subject.send(:login_usable?, ["bob"], ["john", "smith"])).to be false
      end

      it "is false when the profile has a full name" do
        expect(subject.send(:login_usable?, ["john", "smith"], ["john", "smith"])).to be false
      end
    end

    describe "#login_matches_name?" do
      let(:john_smith) { ["john", "smith"] }

      it "is false for a single name" do
        expect(subject.send(:login_matches_name?, "raghotham", ["raghotham"])).to be false
      end

      it "matches usernames containing two of the names, in any order" do
        expect(subject.send(:login_matches_name?, "johnsmith", john_smith)).to be true
        expect(subject.send(:login_matches_name?, "smith-john", john_smith)).to be true
      end

      it "ignores case, digits and punctuation in the username" do
        expect(subject.send(:login_matches_name?, "JohnSmith", john_smith)).to be true
        expect(subject.send(:login_matches_name?, "john-smith-42", john_smith)).to be true
      end

      it "doesn't count names shorter than 3 letters" do
        expect(subject.send(:login_matches_name?, "anli", ["an", "li"])).to be false
      end

      it "doesn't match a username containing only one of the names" do
        expect(subject.send(:login_matches_name?, "johnx", john_smith)).to be false
      end

      it "matches a username part that is one of the names, if it has 5+ letters" do
        expect(subject.send(:login_matches_name?, "nicolas-dds", ["nicolas", "laverde", "manotas"])).to be true
      end

      it "doesn't match a username part shorter than 5 letters" do
        expect(subject.send(:login_matches_name?, "john-x", john_smith)).to be false
      end

      it "matches initial + last name" do
        expect(subject.send(:login_matches_name?, "jsmith", john_smith)).to be true
        expect(subject.send(:login_matches_name?, "j.smith", john_smith)).to be true
        expect(subject.send(:login_matches_name?, "jsmith42", john_smith)).to be true
      end

      it "matches last name + initial" do
        expect(subject.send(:login_matches_name?, "smithj", john_smith)).to be true
      end

      it "matches first name + last initial" do
        expect(subject.send(:login_matches_name?, "johns", john_smith)).to be true
      end

      it "doesn't match other combinations of initials" do
        expect(subject.send(:login_matches_name?, "js", john_smith)).to be false
      end
    end

    describe "#orcid" do
      it "extracts the ORCID from a URL" do
        expect(subject.send(:orcid, { orcid: "https://orcid.org/0000-0001-2345-6789" })).to eq("0000-0001-2345-6789")
      end

      it "uppercases the checksum" do
        expect(subject.send(:orcid, { orcid: "0000-0002-1825-009x" })).to eq("0000-0002-1825-009X")
      end

      it "is empty when missing or invalid" do
        expect(subject.send(:orcid, {})).to eq("")
        expect(subject.send(:orcid, { orcid: "0000-0001" })).to eq("")
      end
    end

    describe "#conflicting_orcids" do
      let(:a) { "0000-0001-2345-6789" }
      let(:b) { "0000-0009-8765-4321" }

      it "returns both ORCIDs when they differ" do
        expect(subject.send(:conflicting_orcids, { orcid: a }, { orcid: b })).to eq([a, b])
      end

      it "is nil when they are the same" do
        expect(subject.send(:conflicting_orcids, { orcid: a }, { orcid: "https://orcid.org/#{a}" })).to be_nil
      end

      it "is nil when either is missing" do
        expect(subject.send(:conflicting_orcids, { orcid: a }, {})).to be_nil
        expect(subject.send(:conflicting_orcids, {}, { orcid: b })).to be_nil
      end
    end
  end

  describe "#best_match" do
    def checker(*names)
      described_class.new(paper_authors: names.map { |n| { name: n } })
    end

    it "is nil without candidates" do
      expect(checker("Jane Doe").best_match({ name: "Jane Doe" }, [])).to be_nil
    end

    it "is nil when no candidate matches" do
      expect(checker("Jane Doe").best_match({ name: "Jane Doe" }, [{ name: "John Smith" }])).to be_nil
    end

    it "prefers an exact match over a probable one" do
      candidates = [{ name: "J. Doe" }, { name: "jane doe" }, { name: "Doe, Jane" }]
      match = checker("Jane Doe").best_match({ name: "Jane Doe" }, candidates)
      expect(match).to eq({ status: :exact, person: { name: "Doe, Jane" }, orcids: nil })
    end

    it "prefers :same over :close" do
      match = checker("Jane Doe").best_match({ name: "Jane Doe" }, [{ name: "J. Doe" }, { name: "JANE DOE" }])
      expect(match[:person]).to eq({ name: "JANE DOE" })
    end

    it "takes the first of equally good matches" do
      match = checker("Jane Doe").best_match({ name: "Jane Doe" }, [{ name: "J. Doe" }, { name: "Jane Q. Doe" }])
      expect(match[:person]).to eq({ name: "J. Doe" })
    end

    it "drops a probable match that is a better match for another author" do
      c = checker("J. Smith", "John Smith")
      expect(c.best_match({ name: "J. Smith" }, [{ name: "John Smith" }])).to be_nil
      expect(c.best_match({ name: "John Smith" }, [{ name: "John Smith" }])[:status]).to eq(:exact)
    end

    it "keeps a match that is just as good for another author" do
      c = checker("John Smith", "Jane Smith")
      expect(c.best_match({ name: "John Smith" }, [{ name: "J. Smith" }])[:status]).to eq(:close)
      expect(c.best_match({ name: "Jane Smith" }, [{ name: "J. Smith" }])[:status]).to eq(:close)
    end

    it "includes conflicting ORCIDs" do
      author = { name: "Jane Doe", orcid: "0000-0001-2345-6789" }
      c = described_class.new(paper_authors: [author])
      match = c.best_match(author, [{ name: "Jane Doe", orcid: "0000-0009-8765-4321" }])
      expect(match[:orcids]).to eq(["0000-0001-2345-6789", "0000-0009-8765-4321"])
    end
  end

  describe "#unmatched" do
    let(:c) { described_class.new(paper_authors: [{ name: "Jane Doe" }, { name: "John Smith" }]) }

    it "is nil for a source that wasn't checked" do
      expect(c.unmatched(nil, [])).to be_nil
    end

    it "is empty without candidates" do
      expect(c.unmatched([], [])).to eq([])
    end

    it "leaves out the chosen matches" do
      expect(c.unmatched([{ name: "J. Doe" }], [{ name: "J. Doe" }])).to eq([])
    end

    it "leaves out people with the same name as an author" do
      expect(c.unmatched([{ login: "jane-alt", name: "Jane Doe" }, { name: "JOHN SMITH" }], [])).to eq([])
    end

    it "lists probable matches that weren't chosen" do
      expect(c.unmatched([{ name: "J. Doe" }], [])).to eq([{ name: "J. Doe" }])
    end

    it "lists people who don't match anyone" do
      expect(c.unmatched([{ name: "Extra Person" }], [nil, nil])).to eq([{ name: "Extra Person" }])
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

    it "has one row per paper author, in order" do
      expect(report[:authors].map { |r| r[:author][:name] }).to eq(paper_authors.map { |a| a[:name] })
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

    it "ignores users regardless of @, case and spaces" do
      contributors = [{ login: "Rev1", name: "" }, { login: "rev2", name: "" }, { login: "REV3", name: "" }, { login: "kept", name: "" }]
      c = described_class.new(paper_authors: [], github_contributors: contributors, ignored_logins: ["@rev1", " REV2 ", "rev3"])
      expect(c.github_contributors.map { |x| x[:login] }).to eq(["kept"])
    end

    it "doesn't fail when ignoring users without GitHub contributors" do
      c = described_class.new(paper_authors: [], ignored_logins: ["@rev1"])
      expect(c.github_contributors).to be_nil
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
      expect(report[:authors].first[:github]).to be_nil
    end

    it "uses empty lists for sources that were checked but are empty" do
      report = described_class.new(paper_authors: paper_authors, zenodo_creators: [], github_contributors: []).check
      expect(report[:zenodo_only]).to eq([])
      expect(report[:github_only]).to eq([])
      expect(report[:authors].map { |r| r[:zenodo] }).to all(be_nil)
    end

    it "lists everyone as unmatched when the paper has no authors" do
      report = described_class.new(paper_authors: [], zenodo_creators: zenodo, github_contributors: github).check
      expect(report[:authors]).to eq([])
      expect(report[:zenodo_only]).to eq(zenodo)
      expect(report[:github_only]).to eq(github)
    end

    it "can check only one of the sources" do
      report = described_class.new(paper_authors: paper_authors, zenodo_creators: zenodo).check
      expect(report[:zenodo_only]).to eq([{ name: "Extra, Person" }])
      expect(report[:github_only]).to be_nil
    end
  end
end
