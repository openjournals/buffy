class DOIWorker < BuffyWorker

  def perform(locals, url, branch='main')
    load_context_and_settings(locals)
    return unless setup_local_repo(url, branch)

    paper = PaperFile.find(path)
    entries = paper.bibtex_entries unless paper.bibtex_error

    if paper.bibtex_error
      respond "Checking the BibTeX entries failed with the following error: \n```\n#{paper.bibtex_error}\n```"
    else
      doi_summary = DOIChecker.new(entries).check_dois
      respond_template :doi_checks, { doi_summary: doi_summary }
    end
  end
end
