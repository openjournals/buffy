require 'bibtex'

class PaperFile
  attr_accessor :paper_path
  attr_accessor :bibtex_entries
  attr_accessor :bibtex_error

  def initialize(path)
    @paper_path = path
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

end