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
