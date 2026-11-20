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
#   :exact   same name, written the same way ("Last, First" and "First Last" are equivalent,
#            and so are "Simon J. Greenhill" and "Simon J Greenhill")
#   :same    same name ignoring case, accents and punctuation
#   :close   probably the same person: same ORCID, a missing middle name or initial,
#            a short form of a name ("Eli" for "Elijah"), a one-letter typo,
#            or a GitHub username built from the author's name.
#            Also the same name when both have an ORCID and they differ.
#   nil      not the same person
class AuthorsChecker

  RANKS = [:exact, :same, :close].freeze

  # A one-letter word followed by a period, like the "J." in "Simon J. Greenhill"
  INITIAL_WITH_PERIOD = /(?<![\p{L}\p{M}])(\p{L})\./

  # Shortest name that counts as a short form of a longer one ("Eli" for "Elijah")
  MIN_SHORT_FORM = 3

  attr_reader :paper_authors, :zenodo_creators, :github_contributors

  def initialize(paper_authors: [], zenodo_creators: nil, github_contributors: nil, ignored_logins: [])
    @paper_authors = paper_authors
    @zenodo_creators = zenodo_creators
    ignored = ignored_logins.map { |l| l.to_s.strip.sub(/^@/, "").downcase }
    @github_contributors = github_contributors&.reject { |c| ignored.include?(c[:login].to_s.downcase) }
  end

  # Returns a hash with:
  #   authors: one row per paper author with its best :zenodo and :github match (or nil)
  #   zenodo_only: Zenodo creators that aren't any paper author's match
  #   github_only: GitHub contributors that aren't any paper author's match
  # A match is { status: :exact | :same | :close, person:, orcids: } where orcids is
  # [author's ORCID, person's ORCID] if both have one and they differ, or nil
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
      zenodo_only: unmatched(zenodo_creators, rows.map { |r| r[:zenodo]&.dig(:person) }),
      github_only: unmatched(github_contributors, rows.map { |r| r[:github]&.dig(:person) })
    }
  end

  # Best match for an author among the candidates. A probable match is discarded
  # if that candidate has a better match with a different author.
  def best_match(author, candidates)
    matches = candidates.filter_map do |candidate|
      status = compare(author, candidate)
      next unless status
      next if RANKS.index(status) > best_rank_with_other_authors(author, candidate)
      { status: status, person: candidate, orcids: conflicting_orcids(author, candidate) }
    end
    matches.min_by { |m| RANKS.index(m[:status]) }
  end

  # Candidates that aren't the chosen match of any paper author. The only ones left out
  # are those with the same name as an author (e.g. a second GitHub account): a merely
  # probable match that wasn't chosen is still listed, so nobody silently disappears.
  def unmatched(candidates, chosen)
    return nil if candidates.nil?
    candidates.reject do |c|
      chosen.include?(c) || paper_authors.any? { |author| [:exact, :same].include?(compare(author, c)) }
    end
  end

  def compare(author, other)
    status = compare_names(author, other)
    # The same name with a different ORCID may be a different person, or a mistake: flag it
    status = :close if [:exact, :same].include?(status) && conflicting_orcids(author, other)
    status
  end

  def compare_names(author, other)
    return :exact if !exact_form(author[:name]).empty? && exact_form(author[:name]) == exact_form(other[:name])

    a_tokens = normalize_name(author[:name]).split
    o_tokens = normalize_name(other[:name]).split

    return :same if !a_tokens.empty? && a_tokens.sort == o_tokens.sort
    return :close if same_orcid?(author, other)
    return :close if similar_names?(a_tokens, o_tokens)
    return :close if other[:login] && login_usable?(o_tokens, a_tokens) && login_matches_name?(other[:login], a_tokens)

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

  # Display name without periods after initials: "Simon J. Greenhill" is the same as "Simon J Greenhill"
  def exact_form(name)
    display_name(name).gsub(INITIAL_WITH_PERIOD, '\1 ').split.join(" ")
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

  def conflicting_orcids(author, other)
    orcids = [orcid(author), orcid(other)]
    orcids if orcids.none?(&:empty?) && orcids.uniq.size == 2
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
    # Each name in one matches a different name in the other, in any order:
    # "Juan Pablo Aguilar" ~ "Juan Pablo Aguilar Calle", "Eli Knaap" ~ "Knaap Elijah"
    shorter, longer = [a, b].sort_by(&:size)
    return true if shorter.size > 1 && all_tokens_matched?(shorter, longer)
    # One-letter typo in names long enough for that to be meaningful
    a.join(" ").length > 8 && DidYouMean::Levenshtein.distance(a.join(" "), b.join(" ")) <= 1
  end

  # Every token in shorter matches a different token in longer. Equal tokens are paired first,
  # so a short form or an initial doesn't take a name that matches another token exactly.
  def all_tokens_matched?(shorter, longer)
    remaining = longer.dup
    shorter.sort_by { |t| longer.include?(t) ? 0 : 1 }.all? do |token|
      index = remaining.index(token) || remaining.index { |other| token_match?(token, other) }
      index && remaining.delete_at(index)
    end
  end

  # Equal names, an initial and a name ("j" ~ "john"), or a short form of a name ("eli" ~ "elijah")
  def token_match?(x, y)
    short, long = [x, y].sort_by(&:length)
    return true if short == long
    (short.length == 1 || short.length >= MIN_SHORT_FORM) && long.start_with?(short)
  end

  # A username only counts as evidence if the profile name doesn't say otherwise: the
  # profile has no name, or just one name that is also one of the author's names
  def login_usable?(profile_tokens, name_tokens)
    profile_tokens.empty? || (profile_tokens.size == 1 && name_tokens.include?(profile_tokens.first))
  end

  # Usernames like "jsmith", "johnsmith", "smith-john", "john-ds" or "smithj" for John Smith
  def login_matches_name?(login, name_tokens)
    return false if name_tokens.size < 2
    login = login.to_s.downcase
    letters = login.gsub(/[^a-z]/, "")
    parts = login.split(/[^a-z]+/)
    first, last = name_tokens.first, name_tokens.last

    return true if name_tokens.count { |t| t.length >= 3 && letters.include?(t) } >= 2
    return true if parts.any? { |p| p.length >= 5 && name_tokens.include?(p) }
    [first[0] + last, last + first[0], first + last[0]].include?(letters)
  end
end
