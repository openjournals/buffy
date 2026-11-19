require 'did_you_mean'

# Compares the list of authors in a paper with the creators of its Zenodo archive
# and with the contributors of its GitHub repository.
#
# Each person is a hash:
#   paper authors:    { name:, orcid: }
#   zenodo creators:  { name:, orcid: }
#   github contribs:  { login:, name:, contributions: }
#
# Comparing two people gives one of these results, from best to worst:
#   :exact   same name, written the same way ("Last, First" and "First Last" are equivalent)
#   :same    same name ignoring case, accents and punctuation
#   :close   probably the same person: same ORCID, a missing middle name or initial,
#            a one-letter typo, or a GitHub username built from the author's name
#   nil      not the same person
class AuthorsChecker

  RANKS = [:exact, :same, :close].freeze

  attr_reader :paper_authors, :zenodo_creators, :github_contributors

  def initialize(paper_authors: [], zenodo_creators: nil, github_contributors: nil, ignored_logins: [])
    @paper_authors = paper_authors
    @zenodo_creators = zenodo_creators
    ignored = ignored_logins.map { |l| l.to_s.strip.sub(/^@/, "").downcase }
    @github_contributors = github_contributors&.reject { |c| ignored.include?(c[:login].to_s.downcase) }
  end

  # Returns a hash with:
  #   authors: one row per paper author with its best :zenodo and :github match (or nil)
  #   zenodo_only: Zenodo creators that don't match any paper author
  #   github_only: GitHub contributors that don't match any paper author
  # A match is { status: :exact | :same | :close, person: }
  # A nil list (instead of an empty one) means that source wasn't checked
  def check
    rows = paper_authors.map do |author|
      {
        author: author,
        zenodo: zenodo_creators && best_match(author, zenodo_creators),
        github: github_contributors && best_match(author, github_contributors)
      }
    end

    {
      authors: rows,
      zenodo_only: unmatched(zenodo_creators),
      github_only: unmatched(github_contributors)
    }
  end

  # Best match for an author among the candidates. A probable match is discarded
  # if that candidate has a better match with a different author.
  def best_match(author, candidates)
    matches = candidates.filter_map do |candidate|
      status = compare(author, candidate)
      next unless status
      next if RANKS.index(status) > best_rank_with_other_authors(author, candidate)
      { status: status, person: candidate }
    end
    matches.min_by { |m| RANKS.index(m[:status]) }
  end

  # People that don't match any paper author (one author can have several GitHub accounts)
  def unmatched(candidates)
    return nil if candidates.nil?
    candidates.reject { |c| paper_authors.any? { |author| compare(author, c) } }
  end

  def compare(author, other)
    return :exact if !display_name(author[:name]).empty? && display_name(author[:name]) == display_name(other[:name])

    a_tokens = normalize_name(author[:name]).split
    o_tokens = normalize_name(other[:name]).split

    return :same if !a_tokens.empty? && a_tokens.sort == o_tokens.sort
    return :close if same_orcid?(author, other)
    return :close if similar_names?(a_tokens, o_tokens)
    return :close if other[:login] && login_matches_name?(other[:login], a_tokens)

    nil
  end

  # Turn "Last, First" into "First Last" and normalize whitespace
  def display_name(name)
    name = name.to_s.strip
    if name.count(",") == 1
      last, first = name.split(",").map(&:strip)
      name = "#{first} #{last}"
    end
    name.split.join(" ")
  end

  # Lowercase display name without accents or punctuation
  def normalize_name(name)
    display_name(name).unicode_normalize(:nfkd)
                      .gsub(/\p{Mn}/, "")
                      .downcase
                      .gsub(/[-‐_.]/, " ")
                      .gsub(/[^\p{L}\p{N}\s]/, "")
                      .split.join(" ")
  end

  private

  def best_rank_with_other_authors(author, candidate)
    ranks = (paper_authors - [author]).filter_map { |other| status = compare(other, candidate); status && RANKS.index(status) }
    ranks.min || RANKS.size
  end

  def same_orcid?(author, other)
    orcid = orcid(author)
    !orcid.empty? && orcid == orcid(other)
  end

  def orcid(person)
    person[:orcid].to_s[/\d{4}-\d{4}-\d{4}-\d{3}[\dX]/i].to_s.upcase
  end

  def similar_names?(a, b)
    return false if a.empty? || b.empty?
    return true if a.size > 1 && b.size > 1 && token_match?(a.first, b.first) && token_match?(a.last, b.last)
    # All names in one are part of the other: "Juan Pablo Aguilar" ~ "Juan Pablo Aguilar Calle"
    shorter, longer = [a, b].sort_by(&:size)
    return true if shorter.size > 1 && (shorter - longer).empty?
    # One-letter typo in names long enough for that to be meaningful
    a.join(" ").length > 8 && DidYouMean::Levenshtein.distance(a.join(" "), b.join(" ")) <= 1
  end

  def token_match?(x, y)
    x == y || (x.length == 1 && y.start_with?(x)) || (y.length == 1 && x.start_with?(y))
  end

  # Usernames like "jsmith", "johnsmith", "smith-john", "john-ds" or "smithj" for John Smith
  def login_matches_name?(login, name_tokens)
    return false if name_tokens.size < 2
    login = login.to_s.downcase
    letters = login.gsub(/[^a-z]/, "")
    parts = login.split(/[^a-z]+/)
    first, last = name_tokens.first, name_tokens.last

    return true if name_tokens.count { |t| t.length > 1 && letters.include?(t) } >= 2
    return true if parts.any? { |p| p.length >= 5 && name_tokens.include?(p) }
    [first[0] + last, last + first[0], first + last[0]].include?(letters)
  end
end
