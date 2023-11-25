require 'bibtex'

class PaperFile
  attr_accessor :paper_path
  attr_accessor :bibtex_entries
  attr_accessor :bibtex_error

  def initialize(path=nil)
    @paper_path = path
    @bibtex_error = "No paper file path" if @paper_path.nil?
  end

  def bib
    return @bib unless @bib.nil?

    parsed_bib = BibTeX.open(bibtex_path, filter: :latex)
    no_filter_bib = BibTeX.open(bibtex_path)

    parsed_bib.data.each_with_index do |entry, i|
      entry.doi = no_filter_bib.data[i].doi if entry.is_a?(BibTeX::Entry) && entry.has_field?('doi')
    end

    @bib = parsed_bib
  end

  def bibtex_entries
    @bibtex_entries ||= bib.data
    @bibtex_entries.keep_if { |entry| !entry.comment? && !entry.preamble? && !entry.string? }

    unless bib.errors.empty?
      @bibtex_error = "Lexical or syntactical errors: \n\n"
      @bibtex_error += bib.errors.map(&:content).join("\n")
    end

    @bibtex_entries
  rescue BibTeX::ParseError => e
    @bibtex_error = e.message
    []
  end

  def bibtex_path
    @bibtex_path ||= "#{File.dirname(paper_path)}/#{bibtex_filename}"
  end

  def bibtex_filename
    metadata = YAML.load_file(metadata_path) rescue {}
    @bibtex_filename = metadata['bibliography']
    if @bibtex_filename.nil?
      @bibtex_error = "Couldn't find bibliography entry in the paper's metadata"
    end
    @bibtex_filename
  end

  def metadata_path
    if paper_path.end_with?('.tex')
      "#{File.dirname(paper_path)}/paper.yml"
    else
      paper_path
    end
  end

  def self.find(search_path)
    paper_path = nil

    if Dir.exist? search_path
      Find.find(search_path).each do |path|
        if path =~ /\/paper\.tex$|\/paper\.md$/
          paper_path = path
          break
        end
      end
    end

    PaperFile.new paper_path
  end

  def text
    return "" if @paper_path.nil? || @paper_path.empty?
    File.open(@paper_path).read
  end

end