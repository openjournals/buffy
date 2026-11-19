require_relative "./spec_helper.rb"

describe PaperFile do

  subject do
    described_class.new("./doc/paper.md")
  end

  describe "Initialization" do
    it "should initialize paper_path" do
      expect(subject.paper_path).to eq("./doc/paper.md")
      expect(subject.bibtex_error).to be_nil
    end

    it "should add error if no path" do
      paper_file = PaperFile.new
      expect(paper_file.bibtex_error).to_not be_nil
    end
  end

  describe "#metadata path" do
    it "should be the paper path if paper is not a .tex file" do
      expect(subject.metadata_path).to eq(subject.paper_path)
      expect(subject.metadata_path).to eq("./doc/paper.md")
    end

    it "should be a paper.yml file if paper is a .tex file" do
      paper = PaperFile.new("./docs/paper.tex")
      expect(paper.metadata_path).to eq("./docs/paper.yml")
    end
  end

  describe "#bibtex_filename" do
    it "should read the metadata file" do
      expect(YAML).to receive(:load_file).with("./doc/paper.md").and_return({'bibliography' => 'paper.bib'})
      expect(subject.bibtex_filename).to eq("paper.bib")
      expect(subject.bibtex_error).to be_nil
    end

    it "should be nil if can't read the metadata file" do
      expect(subject.bibtex_filename).to be_nil
      expect(subject.bibtex_error).to_not be_nil
    end

    it "should set bibtex_error if no bibtex_file" do
      expect(YAML).to receive(:load_file).with("./doc/paper.md").and_return({'bib' => 'paper.bib'})
      expect(subject.bibtex_filename).to be_nil
      expect(subject.bibtex_error).to_not be_nil
    end
  end

  describe "#authors" do
    it "should read the authors from the paper's metadata, with YAML aliases, footnotes and plain names" do
      paper = PaperFile.new(fixture("paper_with_authors.md"))
      expect(paper.authors).to eq([{ name: "Jane Q. Doe", orcid: "0000-0001-2345-6789" },
                                   { name: "Ludwig van Beethoven", orcid: "" },
                                   { name: "Grace Hopper", orcid: "" },
                                   { name: "Ada Lovelace", orcid: "" },
                                   { name: "Alan Turing", orcid: "" }])
    end

    it "should be empty if there's no metadata" do
      expect(PaperFile.new.authors).to eq([])
      expect(subject.authors).to eq([])
    end

    def authors_from(yaml)
      PaperFile.new("paper.md").tap { |p| p.metadata_content = yaml }.authors
    end

    it "should be empty without an authors list" do
      expect(authors_from("title: x")).to eq([])
    end

    it "should be empty if authors isn't a list" do
      expect(authors_from("authors: Jane Doe")).to eq([])
      expect(authors_from("authors:\n  name: Jane Doe")).to eq([])
    end

    it "should read authors written as plain names" do
      expect(authors_from("authors:\n  - Jane Doe\n  - John Smith")).to eq([{ name: "Jane Doe", orcid: "" }, { name: "John Smith", orcid: "" }])
    end

    it "should read the name field" do
      expect(authors_from("authors:\n  - name: Jane Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should read split name fields" do
      expect(authors_from("authors:\n  - given-names: Jane\n    surname: Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should read split name fields nested under name" do
      expect(authors_from("authors:\n  - name:\n      given-names: Jane\n      surname: Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should put all name parts in order" do
      yaml = "authors:\n  - surname: Beethoven\n    suffix: Jr.\n    non-dropping-particle: van\n    given-names: Ludwig\n    dropping-particle: de"
      expect(authors_from(yaml)).to eq([{ name: "Ludwig de van Beethoven Jr.", orcid: "" }])
    end

    it "should skip missing name parts" do
      expect(authors_from("authors:\n  - surname: Doe")).to eq([{ name: "Doe", orcid: "" }])
    end

    it "should skip authors without a name" do
      expect(authors_from("authors:\n  - affiliation: 1\n  - name: ''\n  - name: '   '\n  - Jane Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should skip entries that aren't names or fields" do
      expect(authors_from("authors:\n  - 42\n  - \n  - [a, b]\n  - Jane Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should skip names that aren't text" do
      expect(authors_from("authors:\n  - name: 123")).to eq([])
    end

    it "should remove footnotes" do
      expect(authors_from("authors:\n  - name: Jane Doe^[Corresponding author]")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should remove footnotes with brackets" do
      expect(authors_from("authors:\n  - name: Jane Doe^[Equal [contribution] [1]]")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should remove several footnotes" do
      expect(authors_from("authors:\n  - name: Jane^[a] Doe^[b]")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should keep brackets that aren't footnotes" do
      expect(authors_from("authors:\n  - name: Jane [JD] Doe")).to eq([{ name: "Jane [JD] Doe", orcid: "" }])
    end

    it "should skip names that are only a footnote" do
      expect(authors_from("authors:\n  - name: ^[nobody]")).to eq([])
    end

    it "should strip the ORCID" do
      expect(authors_from("authors:\n  - name: Jane Doe\n    orcid: ' 0000-0001-2345-6789 '")).to eq([{ name: "Jane Doe", orcid: "0000-0001-2345-6789" }])
    end
  end

  describe "#metadata" do
    it "should be empty without a paper" do
      expect(PaperFile.new.metadata).to eq({})
    end

    it "should parse the given content instead of reading the file" do
      paper = PaperFile.new("/does/not/exist/paper.md")
      paper.metadata_content = "title: Given"
      expect(File).to_not receive(:read)
      expect(paper.metadata).to eq({ "title" => "Given" })
    end

    it "should read the paper's file when no content is given" do
      expect(PaperFile.new(fixture("paper_with_authors.md")).metadata["title"]).to eq("Test paper")
    end

    it "should read paper.yml for LaTeX papers" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "paper.yml"), "title: From yml")
        expect(PaperFile.new(File.join(dir, "paper.tex")).metadata).to eq({ "title" => "From yml" })
      end
    end

    it "should only read the front matter of a markdown paper" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "---\ntitle: x\n---\n\n# Summary\n\nText: with: colons"
      expect(paper.metadata).to eq({ "title" => "x" })
    end

    it "should be empty if the file can't be read" do
      expect(PaperFile.new("/does/not/exist/paper.md").metadata).to eq({})
    end

    it "should be empty for invalid YAML" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "title: [unclosed"
      expect(paper.metadata).to eq({})
    end

    it "should be empty if the YAML isn't a map" do
      ["- a\n- b", "just text", ""].each do |content|
        paper = PaperFile.new("paper.md")
        paper.metadata_content = content
        expect(paper.metadata).to eq({})
      end
    end

    it "should allow dates and times" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "date: 2026-07-06\nupdated: 2026-07-06 10:00:00\ntitle: x"
      expect(paper.metadata["title"]).to eq("x")
      expect(paper.metadata["date"]).to eq(Date.new(2026, 7, 6))
    end

    it "should allow YAML aliases" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "a: &x 1\nb: *x"
      expect(paper.metadata).to eq({ "a" => 1, "b" => 1 })
    end

    it "should not create arbitrary objects" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "title: !ruby/object:OpenStruct\n  table: {}"
      expect(paper.metadata).to eq({})
    end

    it "should only parse the content once" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "title: x"
      expect(YAML).to receive(:load).once.and_call_original
      2.times { paper.metadata }
    end
  end

  describe "#bibtex_path" do
    it "should return the path of the bib file from the paper's metadata" do
      expect(YAML).to receive(:load_file).with("./doc/paper.md").and_return({'bibliography' => 'references.bib'})
      expect(subject.bibtex_path).to eq("./doc/references.bib")
    end

    it "should clamp the bibliography filename to its basename to prevent path traversal" do
      expect(YAML).to receive(:load_file).with("./doc/paper.md").and_return({'bibliography' => '../../../../etc/hosts'})
      expect(subject.bibtex_path).to eq("./doc/hosts")
    end

    it "should strip leading directories from the bibliography filename" do
      expect(YAML).to receive(:load_file).with("./doc/paper.md").and_return({'bibliography' => 'subdir/refs.bib'})
      expect(subject.bibtex_path).to eq("./doc/refs.bib")
    end
  end

  describe "#bib" do
    it "should read bibtex file" do
      expect(subject).to receive(:bibtex_path).twice.and_return(fixture("paper.bib"))
      bib = subject.bib
      expect(bib.data.size).to eq(6)
      expect(bib.errors).to be_empty
      expect(bib.data.first.title.value).to eq("The NumPy Array: A Structure for Efficient Numerical Computation")
    end

    it "should find lexical errors" do
      expect(subject).to receive(:bibtex_path).twice.and_return(fixture("paper_with_errors.bib"))

      level = BibTeX.log.level
      BibTeX.log.level = "ERROR"
      bib = subject.bib
      BibTeX.log.level = level

      expect(bib.errors).to_not be_empty
      expect(bib.errors.size).to eq(2)
      expect(bib.errors.first.content).to match(/@article{numpy/)
      expect(bib.errors.last.content).to match(/@article{matplotlib/)
    end
  end

  describe "#bibtex_entries" do
    it "should read bibtex file" do
      expect(subject).to receive(:bibtex_path).twice.and_return(fixture("paper.bib"))
      bibtex_entries = subject.bibtex_entries
      expect(bibtex_entries.size).to eq(6)
      expect(bibtex_entries.first.title.value).to eq("The NumPy Array: A Structure for Efficient Numerical Computation")
      expect(bibtex_entries.first.author.value).to eq("van der Walt, S. and Colbert, S. C. and Varoquaux, G.")
      expect(bibtex_entries.first.doi.value).to eq("10.1109/MCSE.2011.37")
      expect(subject.bibtex_error).to be_nil
    end

    it "should parse latex except for doi field" do
      expect(subject).to receive(:bibtex_path).twice.and_return(fixture("paper.bib"))
      bibtex_entries = subject.bibtex_entries
      expect(bibtex_entries.size).to eq(6)
      expect(bibtex_entries.last.title.value).to eq("The LaTeX test: A Structure")
      expect(bibtex_entries.last.author.value).to eq("PArsed, S. and Van–Hall, S. C. and Varo, G.")
      expect(bibtex_entries.last.doi.value).to eq("10.1109/MCSE.2011--37")
      expect(bibtex_entries.last.pages.value).to eq("22–30")
      expect(subject.bibtex_error).to be_nil
    end

    it "should be empty if errors parsing the file" do
      expect(BibTeX).to receive(:open).and_raise BibTeX::ParseError
      expect(subject.bibtex_entries).to eq([])
    end

    it "should set bibtex_error if lexical errors found" do
      expect(subject).to receive(:bibtex_path).twice.and_return(fixture("paper_with_errors.bib"))

      level = BibTeX.log.level
      BibTeX.log.level = "ERROR"
      bibtex_entries = subject.bibtex_entries
      BibTeX.log.level = level

      expect(bibtex_entries.size).to eq(4)
      expect(subject.bibtex_error).to_not be_nil
      expect(subject.bibtex_error).to match(/@article{numpy/)
      expect(subject.bibtex_error).to match(/@article{matplotlib/)
    end
  end

  describe ".find" do
    it "should return a PaperFile initialized with the paper path if present" do
      expect(Dir).to receive(:exist?).with("/repo/path/").and_return(true)
      expect(Find).to receive(:find).with("/repo/path/").and_return(["lib/papers", "./docs/paper.md", "app"])

      paper_file = PaperFile.find("/repo/path/")

      expect(paper_file).to be_kind_of PaperFile
      expect(paper_file.paper_path).to eq("./docs/paper.md")
    end

    it "should return a nil PaperFile if search_path does not exists" do
      expect(Dir).to receive(:exist?).with("/repo/path/").and_return(false)

      paper_file = PaperFile.find("/repo/path/")

      expect(paper_file).to be_kind_of PaperFile
      expect(paper_file.paper_path).to be_nil
    end

    it "should return a nil PaperFile if no paper file found" do
      expect(Dir).to receive(:exist?).with("/repo/path/").and_return(true)
      allow(Find).to receive(:find).with("/repo/path/").and_return(["lib/papers.pdf", "lib/other_paper.md", "./docs", "app"])

      paper_file = PaperFile.find("/repo/path/")

      expect(paper_file).to be_kind_of PaperFile
      expect(paper_file.paper_path).to be_nil
    end
  end

  describe "#text" do
    it "should return the contents of the paper file" do
      file = OpenStruct.new(read: "paper content")
      expect(File).to receive(:open).with("./path/to/paper.md").and_return(file)

      paper = PaperFile.new("./path/to/paper.md")
      expect(paper.text).to eq("paper content")
    end

    it "should return '' if paper_path is not present" do
      paper = PaperFile.new(nil)
      expect(paper.text).to eq("")

      paper = PaperFile.new("")
      expect(paper.text).to eq("")
    end
  end
end