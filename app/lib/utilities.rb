require 'find'
require 'open3'
require 'uri'

module Utilities

  SAFE_BRANCH_NAME = /\A(?!-)[\w.\-\/]+\z/.freeze

  def clone_repo(url, local_path)
    uri = URI.parse(url.to_s) rescue nil
    return false unless uri && %w[http https].include?(uri.scheme) && uri.host

    FileUtils.mkdir_p(local_path)
    _stdout, _stderr, status = Open3.capture3("git", "clone", "--", uri.to_s, local_path)
    status.success?
  end

  # Shallow clone of the latest commit without any file contents, so it's fast even for
  # big repositories. Files can then be read one by one with read_repo_file.
  def clone_repo_metadata(url, local_path, branch = nil)
    uri = URI.parse(url.to_s) rescue nil
    return false unless uri && %w[http https].include?(uri.scheme) && uri.host

    branch = branch.to_s.strip
    return false unless branch.empty? || branch =~ SAFE_BRANCH_NAME

    command = ["git", "clone", "--quiet", "--depth", "1", "--filter=blob:none", "--no-checkout"]
    command += ["--branch", branch] unless branch.empty?
    command += ["--", uri.to_s, local_path]

    FileUtils.mkdir_p(local_path)
    _stdout, _stderr, status = Open3.capture3(*command)
    status.success?
  end

  # Paths of the regular files (no symlinks or submodules) in a repository cloned with
  # clone_repo_metadata. Paths are binary strings, as git doesn't guarantee any encoding.
  def repo_files(local_path)
    stdout, _stderr, status = Open3.capture3("git", "-C", local_path, "ls-tree", "-r", "-z", "HEAD")
    return [] unless status.success?

    # Each entry is "<mode> <type> <object>\t<path>"
    stdout.b.split("\0").filter_map do |entry|
      info, file_path = entry.split("\t", 2)
      file_path if file_path && info.start_with?("100644 ", "100755 ")
    end
  end

  # Contents of one file of a repository cloned with clone_repo_metadata, or nil if not found
  def read_repo_file(local_path, file_path)
    stdout, _stderr, status = Open3.capture3("git", "-C", local_path, "show", "HEAD:".b + file_path.b)
    status.success? ? stdout.dup.force_encoding(Encoding::UTF_8).scrub : nil
  end

  def change_branch(branch, local_path)
    return true if (branch.nil? || branch.strip.empty?)
    branch = branch.strip
    return false unless branch =~ SAFE_BRANCH_NAME

    _stdout, _stderr, status = Open3.capture3("git", "-C", local_path, "switch", "--", branch)
    status.success?
  end

  def run_cloc(local_path)
    result, _stderr, status = Open3.capture3("cloc", "--quiet", local_path)
    status.success? ? result : nil
  end

end
