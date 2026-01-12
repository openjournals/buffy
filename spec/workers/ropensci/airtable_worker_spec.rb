require_relative "../../spec_helper.rb"
require "date"

describe Ropensci::AirtableWorker do

  describe "perform" do
    before do
      @config = {}
      @locals = { "bot_name" => "ropensci-review-bot", "issue_id" => 33, "repo" => "ropensci/tests", "sender" => "editor1" }
      @worker = described_class.new
      disable_github_calls_for(@worker)
    end

    it "should run assign_reviewer action" do
      expect(@worker).to receive(:assign_reviewer)
      @worker.perform("assign_reviewer", @config, @locals, {})
    end

    it "should run remove_reviewer action" do
      expect(@worker).to receive(:remove_reviewer)
      @worker.perform("remove_reviewer", @config, @locals, {})
    end

    it "should run submit_review action" do
      expect(@worker).to receive(:submit_review).with(@config)
      @worker.perform("submit_review", @config, @locals, {})
    end

    it "should run submit_author_response action" do
      expect(@worker).to receive(:submit_author_response)
      @worker.perform("submit_author_response", @config, @locals, {})
    end

    it "should run slack_invites action" do
      expect(@worker).to receive(:slack_invites)
      @worker.perform("slack_invites", @config, @locals, {})
    end

    it "should run clear_assignments action" do
      expect(@worker).to receive(:clear_assignments)
      @worker.perform("clear_assignments", @config, @locals, {})
    end

    it "should run package_and_authors action" do
      expect(@worker).to receive(:package_and_authors)
      @worker.perform("package_and_authors", @config, @locals, {})
    end

    it "should load airtable config and params" do
      @worker.perform("action", @config, @locals, {})
      expect(@worker.airtable_config[:api_key]).to eq("ropensci_airtable_api_key_abcde")
      expect(@worker.airtable_config[:base_id]).to eq("ropensci_airtable_base_id_12345")
    end

    it "should load params" do
      @worker.perform("action", @config, @locals, { reviewer: "tester", package_name: "A" })
      expect(@worker.params.reviewer).to eq("tester")
      expect(@worker.params.package_name).to eq("A")
    end
  end

  describe "#assign_reviewer" do
    before do
      @worker = described_class.new
      @worker.context = OpenStruct.new({repo: "testing/new_package", issue_id: "33"})
      @worker.params = OpenStruct.new({ reviewer: "@reviewer21", package_name: "TestPackage"})
      @worker.airtable_config = {api_key: "ABC", base_id: "123"}
      disable_github_calls_for(@worker)
    end

    it "should get reviewer github user" do
      expect(@worker).to receive(:get_user).with("reviewer21")
      @worker.assign_reviewer
    end

    it "should respond to GitHub if user is invalid" do
      expect(@worker).to receive(:get_user).with("reviewer21").and_return(nil)
      expect(@worker).to receive(:respond).with("I could not find user @reviewer21")

      @worker.assign_reviewer
    end

    describe "connects with Airtable" do
      let(:reviewer_in_airtable) { OpenStruct.new({current_assignment: "", id: 111, save: true}) }
      let(:reviewers_table) { double(all: [reviewer_in_airtable], create: [reviewer_in_airtable]) }
      let(:reviews_table) { double(create: true) }

      before do
        reviewer = OpenStruct.new({ login: "reviewer21", name: "Rev Iewer", email: "rev@iwe.rs" })
        expect(@worker).to receive(:get_user).with("reviewer21").and_return(reviewer)
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "reviewers-prod").and_return(reviewers_table)
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "reviews").and_return(reviews_table)
      end

      it "should retrieve user from reviewers table" do
        expect(reviewers_table).to receive(:all).and_return([reviewer_in_airtable])
        expect(reviewers_table).to_not receive(:create)

        @worker.assign_reviewer
      end

      it "should create user in reviewers table if not present" do
        expect(reviewers_table).to receive(:all).and_return([])
        expect(reviewers_table).to receive(:create).with(github: "reviewer21", name: "Rev Iewer", email: "rev@iwe.rs").and_return(reviewer_in_airtable)

        @worker.assign_reviewer
      end

      it "should update reviewer current assignment" do
        expect(reviewer_in_airtable.current_assignment).to eq("")
        @worker.assign_reviewer
        expect(reviewer_in_airtable.current_assignment).to eq("https://github.com/testing/new_package/issues/33")
      end

      it "should create entry in the reviews table" do
        expect(reviews_table).to receive(:create).with(id_no: "33",
                                                       github: [111],
                                                       onboarding_url: "https://github.com/testing/new_package/issues/33",
                                                       package: "TestPackage")

        @worker.assign_reviewer
      end

      it "should respond to GitHub with form link" do
        expected_response = "@reviewer21: If you haven't done so, please fill [this form](https://airtable.com/shrnfDI2S9uuyxtDw) for us to update our reviewers records."
        expect(@worker).to receive(:respond).with(expected_response)

        @worker.assign_reviewer
      end
    end
  end

  describe "#remove_reviewer" do
    before do
      @worker = described_class.new
      @worker.context = OpenStruct.new({repo: "testing/new_package", issue_id: "33"})
      @worker.params = OpenStruct.new({ reviewer: "@reviewer21"})
      @worker.airtable_config = {api_key: "ABC", base_id: "123"}
      disable_github_calls_for(@worker)
    end

    describe "connects with Airtable" do
      let(:reviewer_entry) { OpenStruct.new({current_assignment: "http://current.url", id: 111, save: true}) }
      let(:review_entry) { OpenStruct.new({destroy: true}) }
      let(:reviewers_table) { double(all: [reviewer_entry]) }
      let(:reviews_table) { double(all: [review_entry]) }

      before do
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "reviewers-prod").and_return(reviewers_table)
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "reviews").and_return(reviews_table)
      end

      it "should update current assignment in reviewers table" do
        expect(reviewers_table).to receive(:all).and_return([reviewer_entry])
        expect(reviewer_entry).to receive(:save)
        @worker.remove_reviewer
        expect(reviewer_entry.current_assignment).to eq("")
      end

      it "should not update current assignment if user is not in the reviewers table" do
        expect(reviewers_table).to receive(:all).and_return([])
        expect(reviewer_entry).to_not receive(:save)
        @worker.remove_reviewer
      end

      it "should delete entry in the reviews table" do
        expect(reviews_table).to receive(:all).and_return([review_entry])
        expect(review_entry).to receive(:destroy)

        @worker.remove_reviewer
      end

      it "should not delete entry in the reviews table if is not present" do
        expect(reviews_table).to receive(:all).and_return([])
        expect(review_entry).to_not receive(:destroy)

        @worker.remove_reviewer
      end
    end
  end

  describe "#submit_review" do
    before do
      @worker = described_class.new
      @worker.context = OpenStruct.new({repo: "testing/new_package", issue_id: "33"})
      @worker.params = OpenStruct.new({ reviewer: "@reviewer21",
                                        review_time: "9.5",
                                        review_date: Time.now.to_s,
                                        review_url: "review-url",
                                        reviewers: "@reviewer21, @reviewer42",
                                        package_name: "great_package",
                                        package_authors: ["@first-author", "@other_author"] })
      @worker.airtable_config = {api_key: "ABC", base_id: "123"}
      @responder_config = OpenStruct.new({ label_when_all_reviews_in: "4/review-in-awaiting-changes",
                                           unlabel_when_all_reviews_in: "3/reviewer(s)-assigned" })
      disable_github_calls_for(@worker)
    end

    describe "connects with Airtable" do
      let(:review_in_airtable) { OpenStruct.new({github: "reviewer21", save: true}) }
      let(:reviews_table) { double(all: [review_in_airtable], update: [review_in_airtable]) }
      let(:packages_table) { double(all: [OpenStruct.new({id: 33})]) }

      before do
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "reviews").and_return(reviews_table)
      end

      it "should update reviewer's review" do
        expected_airtable_query = "AND({github} = 'reviewer21', {id_no} = '33')"
        expect(reviews_table).to receive(:all).with({filter: expected_airtable_query}).and_return([review_in_airtable])
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "packages").and_return(packages_table)

        expect(review_in_airtable["review_url"]).to be_nil
        expect(review_in_airtable["review_hours"]).to be_nil
        expect(review_in_airtable["review_date"]).to be_nil

        expect(review_in_airtable).to receive(:save)

        @worker.submit_review({})

        expect(review_in_airtable["review_url"]).to eq("review-url")
        expect(review_in_airtable["review_hours"]).to eq("9.5")
        expect(review_in_airtable["review_date"]).to eq(Time.now.strftime("%Y-%m-%d"))
        expect(review_in_airtable["packages"]).to eq([33])
      end

      it "should reply a success message" do
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "packages").and_return(packages_table)
        expect(@worker).to receive(:respond).with("Logged review for _reviewer21_ (hours: 9.5)")
        @worker.submit_review({})
      end

      it "should reply a warning message if no review entry" do
        expected_airtable_query = "AND({github} = 'reviewer21', {id_no} = '33')"
        expect(reviews_table).to receive(:all).with({filter: expected_airtable_query}).and_return([])
        expect(Airrecord).to_not receive(:table).with("ABC", "123", "packages")

        expect(@worker).to receive(:respond).with("Couldn't find entry for _reviewer21_ in the reviews log")
        @worker.submit_review({})
      end

      it "should update label when number of reviews and reviewers is the same and set reminder for authors" do
        reviewer_query = "AND({github} = 'reviewer21', {id_no} = '33')"
        expect(reviews_table).to receive(:all).with({filter: reviewer_query}).and_return([review_in_airtable])
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "packages").and_return(packages_table)

        expected_airtable_query = "AND(OR({github} = 'reviewer21', {github} = 'reviewer42'), {id_no} = '33')"
        review_21 = { "review_url" => "review-url-21" }
        review_42 = { "review_url" => "review-url-42" }
        expect(reviews_table).to receive(:all).with({filter: expected_airtable_query}).and_return([review_21, review_42])

        expect(@worker).to receive(:label_issue).with(["4/review-in-awaiting-changes"])
        expect(@worker).to receive(:unlabel_issue).with("3/reviewer(s)-assigned")

        expected_locals = {"issue_id"=>"33", "repo"=>"testing/new_package"}
        expected_reminder = "@first-author, @other_author: please post your response with `@ropensci-review-bot submit response <url to issue comment>` if you haven't done so already (this is an automatic reminder).\n\nHere's the author guide for response. https://devguide.ropensci.org/authors-guide.html"
        expect(AsyncMessageWorker).to receive(:perform_at) do |msg_scheduled_at, msg_locals, msg_text|
          expect(msg_scheduled_at.to_date).to eq((Time.now + (12*86400)).to_date)
          expect(msg_locals).to eq(expected_locals)
          expect(msg_text).to eq(expected_reminder)
        end

        @worker.submit_review(@responder_config)
      end

      it "should not update label if pending reviews" do
        reviewer_query = "AND({github} = 'reviewer21', {id_no} = '33')"
        expect(reviews_table).to receive(:all).with({filter: reviewer_query}).and_return([review_in_airtable])
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "packages").and_return(packages_table)

        expected_airtable_query = "AND(OR({github} = 'reviewer21', {github} = 'reviewer42'), {id_no} = '33')"
        review_21 = { "review_url" => "review-url-21" }
        review_42 = { "review_url" => nil }
        expect(reviews_table).to receive(:all).with({filter: expected_airtable_query}).and_return([review_21, review_42])

        expect(@worker).to_not receive(:label_issue)
        expect(@worker).to_not receive(:unlabel_issue)
        @worker.submit_review(@responder_config)
      end

      it "should update labels only if labels params exists" do
        reviewer_query = "AND({github} = 'reviewer21', {id_no} = '33')"
        expect(reviews_table).to receive(:all).with({filter: reviewer_query}).and_return([review_in_airtable])
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "packages").and_return(packages_table)

        expected_airtable_query = "AND(OR({github} = 'reviewer21', {github} = 'reviewer42'), {id_no} = '33')"
        expect(reviews_table).to_not receive(:all).with({filter: expected_airtable_query})

        expect(@worker).to_not receive(:label_issue)
        expect(@worker).to_not receive(:unlabel_issue)
        @worker.submit_review({ label_when_all_reviews_in: "", unlabel_when_all_reviews_in: nil })
      end
    end
  end

  describe "#submit_author_response" do
    before do
      @worker = described_class.new
      @worker.context = OpenStruct.new({repo: "testing/new_package", issue_id: "42"})
      @worker.params = OpenStruct.new({ author_response_id: "great-package 123456789",
                                        author_response_url: "https://github.com/ropensci/testing/issues/32#issuecomment-123456789",
                                        submitting_date: Time.now.strftime("%Y-%m-%d"),
                                        package_name: "great-package" })
      @worker.airtable_config = {api_key: "ABC", base_id: "123"}

      disable_github_calls_for(@worker)
    end

    describe "connects with Airtable" do
      let(:airtable_author_responses_table) { double(create: true) }
      let(:packages_table) { double(all: []) }

      before do
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "packages").and_return(packages_table)
      end

      it "should create author-response entry" do
        expected_airtable_query = "{package-name} = 'great-package'"
        expect(packages_table).to receive(:all).with({filter: expected_airtable_query}).and_return([OpenStruct.new({id: 33})])

        expect(Airrecord).to receive(:table).once.with("ABC", "123", "author-responses").and_return(airtable_author_responses_table)

        expected_values = { id_no: "great-package 123456789",
                            response_date: Time.now.strftime("%Y-%m-%d"),
                            package: [33],
                            response_url: "https://github.com/ropensci/testing/issues/32#issuecomment-123456789" }
        expect(airtable_author_responses_table).to receive(:create).with(expected_values)

        @worker.submit_author_response
      end

      it "should reply a success message" do
        expected_airtable_query = "{package-name} = 'great-package'"
        expect(packages_table).to receive(:all).with({filter: expected_airtable_query}).and_return([OpenStruct.new({id: 33})])
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "author-responses").and_return(airtable_author_responses_table)
        expect(@worker).to receive(:respond).with("Logged author response!")

        @worker.submit_author_response
      end

      it "should reply a warning message if no package entry" do
        expected_airtable_query = "{package-name} = 'great-package'"
        expect(packages_table).to receive(:all).with({filter: expected_airtable_query}).and_return([])


        expect(@worker).to receive(:respond).with("Couldn't find entry for _great-package_ in the packages log")
        @worker.submit_author_response
      end
    end
  end

  describe "#slack_invites" do
    before do
      @worker = described_class.new
      @worker.context = OpenStruct.new({repo: "testing/new_package", issue_id: "33"})
      @worker.airtable_config = {api_key: "ABC", base_id: "123"}
      disable_github_calls_for(@worker)
    end

    describe "updates slack-invites Airtable" do
      let(:slack_invites_table) { double(create: true) }
      let(:expected_params) { {package: "TestPackage", date: Date.today.strftime("%Y-%m-%d")} }
      let(:reviewer1) { OpenStruct.new(login: "rev1", name: "Reviewer One", email: "one@reviewe.rs") }
      let(:reviewer2) { OpenStruct.new(login: "rev2", name: "Reviewer Two", email: "two@reviewe.rs") }
      let(:author1) { OpenStruct.new(login: "author1", name: "Author One", email: "one@autho.rs") }
      let(:author2) { OpenStruct.new(login: "other1", name: "Author Two", email: "two@autho.rs") }
      let(:author3) { OpenStruct.new(login: "other2", name: "Author Three", email: "three@autho.rs") }

      before do
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "slack-invites").and_return(slack_invites_table)
        allow(@worker).to receive(:get_user).with(nil).and_return(nil)
        allow(@worker).to receive(:get_user).with("rev1").and_return(reviewer1)
        allow(@worker).to receive(:get_user).with("rev2").and_return(reviewer2)
        allow(@worker).to receive(:get_user).with("author1").and_return(author1)
        allow(@worker).to receive(:get_user).with("other1").and_return(author2)
        allow(@worker).to receive(:get_user).with("other2").and_return(author3)
      end

      it "should create an entry for the author" do
        @worker.params = OpenStruct.new({author: "author1", reviewers: [], author_others: [], package_name: "TestPackage"})
        expected_params_author_1 = expected_params.merge({ name: "Author One",
                                                           email: "one@autho.rs",
                                                           github: "https://github.com/author1",
                                                           role: "author1" })
        expect(slack_invites_table).to receive(:create).with(expected_params_author_1)
        @worker.slack_invites
      end

      it "should create an entry for each reviewer" do
        @worker.params = OpenStruct.new({author: nil, reviewers: ["rev1", "rev2"], author_others: [], package_name: "TestPackage"})
        expected_params_reviewer_1 = expected_params.merge({ name: "Reviewer One",
                                                             email: "one@reviewe.rs",
                                                             github: "https://github.com/rev1",
                                                             role: "reviewer" })
        expected_params_reviewer_2 = expected_params.merge({ name: "Reviewer Two",
                                                             email: "two@reviewe.rs",
                                                             github: "https://github.com/rev2",
                                                             role: "reviewer" })
        expect(slack_invites_table).to receive(:create).with(expected_params_reviewer_1)
        expect(slack_invites_table).to receive(:create).with(expected_params_reviewer_2)
        @worker.slack_invites
      end

      it "should create an entry for each other author" do
        @worker.params = OpenStruct.new({author: nil, reviewers: [], author_others: ["other1", "other2"], package_name: "TestPackage"})
        expected_params_author_2 = expected_params.merge({ name: "Author Two",
                                                           email: "two@autho.rs",
                                                             github: "https://github.com/other1",
                                                           role: "author-others" })
        expected_params_author_3 = expected_params.merge({ name: "Author Three",
                                                           email: "three@autho.rs",
                                                             github: "https://github.com/other2",
                                                           role: "author-others" })
        expect(slack_invites_table).to receive(:create).with(expected_params_author_2)
        expect(slack_invites_table).to receive(:create).with(expected_params_author_3)
        @worker.slack_invites
      end

      it "should create entries for all authors and reviewers" do
        @worker.params = OpenStruct.new({author: "author1", reviewers: ["rev1", "rev2"], author_others: ["other1", "other2"], package_name: "TestPackage"})
        expected_params_author_1 = expected_params.merge({ name: "Author One",
                                                           email: "one@autho.rs",
                                                           github: "https://github.com/author1",
                                                           role: "author1" })
        expected_params_reviewer_1 = expected_params.merge({ name: "Reviewer One",
                                                             email: "one@reviewe.rs",
                                                             github: "https://github.com/rev1",
                                                             role: "reviewer" })
        expected_params_reviewer_2 = expected_params.merge({ name: "Reviewer Two",
                                                             email: "two@reviewe.rs",
                                                             github: "https://github.com/rev2",
                                                             role: "reviewer" })
        expected_params_author_2 = expected_params.merge({ name: "Author Two",
                                                           email: "two@autho.rs",
                                                             github: "https://github.com/other1",
                                                           role: "author-others" })
        expected_params_author_3 = expected_params.merge({ name: "Author Three",
                                                           email: "three@autho.rs",
                                                             github: "https://github.com/other2",
                                                           role: "author-others" })
        expect(slack_invites_table).to receive(:create).with(expected_params_author_1)
        expect(slack_invites_table).to receive(:create).with(expected_params_reviewer_1)
        expect(slack_invites_table).to receive(:create).with(expected_params_reviewer_2)
        expect(slack_invites_table).to receive(:create).with(expected_params_author_2)
        expect(slack_invites_table).to receive(:create).with(expected_params_author_3)
        @worker.slack_invites
      end

      it "should should use login if name is not defined" do
        author1.name = nil
        @worker.params = OpenStruct.new({author: "author1", reviewers: [], author_others: [], package_name: "TestPackage"})
        expected_params_author_1 = expected_params.merge({ name: "author1 (GitHub username)",
                                                           email: "one@autho.rs",
                                                           github: "https://github.com/author1",
                                                           role: "author1" })
        expect(slack_invites_table).to receive(:create).with(expected_params_author_1)
        @worker.slack_invites
      end
    end
  end

  describe "#clear_assignments" do
    before do
      @worker = described_class.new
      @worker.context = OpenStruct.new({repo: "testing/approved-package", issue_id: "42"})
      @worker.params = OpenStruct.new({ reviewers: ["@reviewer21", "@reviewer33"]})
      @worker.airtable_config = {api_key: "ABC", base_id: "123"}
      disable_github_calls_for(@worker)
    end

    describe "connects with Airtable" do
      let(:reviewer_entry_1) { OpenStruct.new({current_assignment: "http://current.url", id: 111, save: true}) }
      let(:reviewer_entry_2) { OpenStruct.new({current_assignment: "http://current.review", id: 222, save: true}) }
      let(:reviewers_table) { double(all: [reviewer_entry_1, reviewer_entry_2]) }

      before do
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "reviewers-prod").and_return(reviewers_table)
      end

      it "should remove current assignments in reviewers table" do
        expect(reviewers_table).to receive(:all).exactly(2).and_return([reviewer_entry_1], [reviewer_entry_2])
        expect(reviewer_entry_1).to receive(:save)
        expect(reviewer_entry_2).to receive(:save)
        @worker.clear_assignments
        expect(reviewer_entry_1.current_assignment).to eq("")
        expect(reviewer_entry_2.current_assignment).to eq("")
      end

      it "should not clear current assignment if user is not in the reviewers table" do
        expect(reviewers_table).to receive(:all).exactly(2).and_return([])
        expect(reviewer_entry_1).to_not receive(:save)
        expect(reviewer_entry_2).to_not receive(:save)
        @worker.clear_assignments
      end
    end
  end

  describe "#package_and_authors" do
    before do
      @worker = described_class.new
      @worker.context = OpenStruct.new({repo: "testing/new_package", issue_id: "33"})
      @worker.params = OpenStruct.new({
        author1: "first_author",
        author_others: ["second_author", "third_author"],
        submission_url: "https://github.com/ropensci/test-submissions/issues/15",
        repo_url: "https://github.com/ropensci-packages/great-package",
        package_name: "great-package",
        editor: "editor33",
        submitted_at: "2021-09-06T11:08:23Z"
      })
      @worker.airtable_config = {api_key: "ABC", base_id: "123"}
      disable_github_calls_for(@worker)
    end

    describe "connects with Airtable" do
      let(:authors_table) { double(all: [], create: OpenStruct.new({github: "new_author", id: "3333"})) }
      let(:packages_table) { double(all: [], create: OpenStruct.new({id: "package-id2345"})) }

      before do
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "authors").and_return(authors_table)
        expect(Airrecord).to receive(:table).once.with("ABC", "123", "packages").and_return(packages_table)
      end

      it "should find or create entry for author1" do
        expect(authors_table).to receive(:all).with({filter: "{github} = 'first_author'"}).and_return([])
        expect(authors_table).to receive(:create).with({github: "first_author"})

        @worker.package_and_authors
      end

      it "should find or create entries for author_others" do
        expect(authors_table).to receive(:all).with({filter: "{github} = 'second_author'"}).and_return([OpenStruct.new({github: "second_author", id: "2222"})])
        expect(authors_table).to_not receive(:create).with({github: "second_author"})
        expect(authors_table).to receive(:all).with({filter: "{github} = 'third_author'"}).and_return([])
        expect(authors_table).to receive(:create).with({github: "third_author"})

        @worker.package_and_authors
      end

      it "should create new package entry" do
        expect(authors_table).to receive(:create).with({github: "first_author"}).and_return(OpenStruct.new({id: "111"}))
        expect(authors_table).to receive(:create).with({github: "second_author"}).and_return(OpenStruct.new({id: "222"}))
        expect(authors_table).to receive(:create).with({github: "third_author"}).and_return(OpenStruct.new({id: "333"}))

        expect(packages_table).to receive(:all).with({filter: "{package-name} = 'great-package'"}).and_return([])
        expect(packages_table).to receive(:create).with({
                                                          "package-name" => "great-package",
                                                          "submission-url" => "https://github.com/ropensci/test-submissions/issues/15",
                                                          "repo-url" => "https://github.com/ropensci-packages/great-package",
                                                          "submission-date" => "2021-09-06",
                                                          "editor" => "editor33",
                                                          "author1" => ["111"],
                                                          "author-others" => ["222", "333"]
                                                        })

        @worker.package_and_authors
      end

      it "should not create package entry if already present" do
        expect(packages_table).to receive(:all).with({filter: "{package-name} = 'great-package'"}).and_return([OpenStruct.new({"package-name" => "great-package", id: "12345"})])
        expect(packages_table).to_not receive(:create)

        @worker.package_and_authors
      end
    end
  end
end
