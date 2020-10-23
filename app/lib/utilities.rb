require 'find'
require 'open3'

module Utilities

  # How different are two strings?
  # https://en.wikipedia.org/wiki/Levenshtein_distance
  def levenshtein_distance(s, t)
    m = s.length
    n = t.length

    return m if n == 0
    return n if m == 0
    d = Array.new(m+1) {Array.new(n+1)}

    (0..m).each {|i| d[i][0] = i}
    (0..n).each {|j| d[0][j] = j}
    (1..n).each do |j|
      (1..m).each do |i|
        d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
                    d[i-1][j-1]       # no operation required
                  else
                    [ d[i-1][j]+1,    # deletion
                      d[i][j-1]+1,    # insertion
                      d[i-1][j-1]+1,  # substitution
                    ].min
                  end
      end
    end

    d[m][n]
  end

  def similar?(string_1, string_2)
    levenshtein_distance(string_1, string_2) < 3
  end

  def find_paper_file(search_path)
    paper_path = nil

    Find.find(search_path).each do |path|
      if path =~ /paper\.tex$|paper\.md$/
        paper_path = path
        break
      end
    end

    paper_path
  end

  def clone_repo(url, local_path)
    url = URI.extract(url.to_s).first
    return false if url.nil?

    stdout, stderr, status = Open3.capture3 "git clone #{url} #{local_path}"
    status.success?
  end

  def change_branch(branch, local_path)
    stdout, stderr, status = Open3.capture3 "git -C #{local_path} checkout #{branch}"
    status.success?
  end

end
