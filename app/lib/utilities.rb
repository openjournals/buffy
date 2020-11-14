require 'find'
require 'open3'

module Utilities

  def clone_repo(url, local_path)
    url = URI.extract(url.to_s).first
    return false if url.nil?

    FileUtils.mkdir_p(local_path)
    stdout, stderr, status = Open3.capture3 "git clone #{url} #{local_path}"
    status.success?
  end

  def change_branch(branch, local_path)
    return true if (branch.nil? || branch.strip.empty?)
    stdout, stderr, status = Open3.capture3 "git -C #{local_path} checkout #{branch}"
    status.success?
  end

  def run_cloc(local_path)
    result, stderr, status = Open3.capture3("cloc --quiet #{local_path}")
    status.success? ? result : nil
  end

  def run_gitinspector(local_path)
    result, stderr, status = Open3.capture3("PYTHONIOENCODING=utf-8 gitinspector #{local_path}")
    status.success? ? result : nil
  end

end
