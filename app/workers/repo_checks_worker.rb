class RepoChecksWorker < BuffyWorker

  def perform(locals, url, branch, checks)
    load_context_and_settings(locals)
    return unless setup_local_repo(url, branch)

    cleanup
  end
end
