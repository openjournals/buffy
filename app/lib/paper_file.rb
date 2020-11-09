require 'bibtex'

class PaperFile
  attr_accessor :paper_path
  attr_accessor :bibtex_entries
  attr_accessor :bibtex_error

  def initialize(path=nil)
    @paper_path = path
    @bibtex_error = "No paper file path" if @paper_path.nil?
  end

  def bibtex_entries
    @bibtex_entries ||= BibTeX.open(bibtex_path, filter: :latex).data
    @bibtex_entries.keep_if { |entry| !entry.comment? && !entry.preamble? && !entry.string? }
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
        if path =~ /paper\.tex$|paper\.md$/
          paper_path = path
          break
        end
      end
    end

    PaperFile.new paper_path
  end

end