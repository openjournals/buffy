require_relative "../../spec_helper.rb"


describe Openjournals::ReviewersListWithExternalCallResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci add @arfon to reviewers")
      expect(@responder.event_regex).to match("@botsci add   @arfon to reviewers")
      expect(@responder.event_regex).to match("@botsci add @arfon  to reviewers")
      expect(@responder.event_regex).to match("@botsci add   @arfon    to reviewers")
      expect(@responder.event_regex).to match("@botsci add @arfon as reviewer")
      expect(@responder.event_regex).to match("@botsci add me as reviewer")
      expect(@responder.event_regex).to match("@botsci remove me from reviewers")
      expect(@responder.event_regex).to match("@botsci remove @arfon from reviewers  ")
      expect(@responder.event_regex).to match("@botsci remove @arfon from reviewers  \r\n")
      expect(@responder.event_regex).to match("@botsci remove @arfon from reviewers  \r\n more ")
      expect(@responder.event_regex).to_not match("@botsci add to reviewers")
      expect(@responder.event_regex).to_not match("@botsci add@arfon to reviewers")
      expect(@responder.event_regex).to_not match("@botsci add @arfonto reviewers")
      expect(@responder.event_regex).to_not match("@botsci remove   from reviewers")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      @responder.context = OpenStruct.new(sender: "editor", issue_id: "3342", issue_title: "[REVIEW]: Test")

      disable_github_calls_for(@responder)
      allow(@responder.logger).to receive(:warn)
    end

    describe "adding new reviewer" do
      before do
        @msg = "@botsci add @xuanxu as reviewer"
        @responder.match_data = @responder.event_regex.match(@msg)

        issue_body = "...Reviewers: <!--reviewers-list-->@arfon<!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)
      end

      it "should add new user to the reviewers list in the body of the issue" do
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon, @xuanxu<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        @responder.process_message(@msg)
      end

      it "should respond to github" do
        expect(@responder).to receive(:respond).with("@xuanxu added to the reviewers list!")
        @responder.process_message(@msg)
      end

      it "should accept to or as syntax" do
        msg = "@botsci add @xuanxu to reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon, @xuanxu<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        @responder.process_message(msg)
      end

      it "should accept assign syntax" do
        msg = "@botsci assign @xuanxu to reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon, @xuanxu<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        @responder.process_message(msg)

        msg = "@botsci assign @xuanxu as reviewer"
        @responder.match_data = @responder.event_regex.match(msg)
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon, @xuanxu<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        @responder.process_message(msg)
      end

      it "should accept 'me' as the new reviewer" do
        msg = "@botsci add me as reviewer"
        @responder.match_data = @responder.event_regex.match(msg)
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon, @editor<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        expect(@responder).to receive(:respond).with("@editor added to the reviewers list!")
        @responder.process_message(msg)
      end

      it "should not add user if already present in the reviewers list" do
        msg = "@botsci add @arfon to reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        expect(@responder).to_not receive(:update_issue)
        expect(@responder).to receive(:respond).with("@arfon is already included in the reviewers list")
        @responder.process_message(msg)
      end

      it "should not add as assignee/collaborator if not configured" do
        expect(@responder).to_not receive(:add_collaborator)
        expect(@responder).to_not receive(:add_assignee)
        @responder.process_message(@msg)
      end

      it "should add as collaborator if configured" do
        @responder.params[:add_as_collaborator] = true
        expect(@responder).to receive(:add_collaborator)
        expect(@responder).to_not receive(:add_assignee)
        @responder.process_message(@msg)
      end

      it "should add as assignee if configured" do
        @responder.params[:add_as_assignee] = true
        expect(@responder).to_not receive(:add_collaborator)
        expect(@responder).to receive(:add_assignee)
        @responder.process_message(@msg)
      end

      it "should not call Reviewers API if no configured and log error" do
        expect(Faraday).to_not receive(:post)
        expected_error = "Error assigning review 3342 to @xuanxu: Missing configuration values for the API: host's URL and/or API Token"
        expect(@responder.logger).to receive(:warn).with(expected_error)
        @responder.process_message(@msg)
      end

      it "should not call Reviewers API if issue is not a review" do
        @responder.context[:issue_title] = "[PRE REVIEW]: Test"
        @responder.env[:reviewers_host_url] = "https://reviewers.test"
        @responder.env[:reviewers_api_token] = "123456789ABC"

        expect(OJRA::Client).to_not receive(:new)
        expect(Faraday).to_not receive(:post)
        @responder.process_message(@msg)
      end

      it "should call Reviewers API" do
        @responder.env[:reviewers_host_url] = "https://reviewers.test"
        @responder.env[:reviewers_api_token] = "123456789ABC"

        client_double = instance_double(OJRA::Client)
        expect(OJRA::Client).to receive(:new).with("https://reviewers.test", "123456789ABC").and_return(client_double)
        expect(client_double).to receive(:assign_reviewers).with("@xuanxu", "3342").and_return(true)
        expect(client_double).to receive(:error_msg).and_return(nil)
        expect(@responder.logger).to_not receive(:warn)
        @responder.process_message(@msg)
      end
    end

    describe "removing a reviewer" do
      before do
        @msg = "@botsci remove @xuanxu from reviewers"
        @responder.match_data = @responder.event_regex.match(@msg)

        issue_body = "...Reviewers: <!--reviewers-list-->@arfon, @xuanxu<!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)
      end

      it "should remove user from the reviewers list in the body of the issue" do
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        @responder.process_message(@msg)
      end

      it "should accept to or as syntax" do
        msg = "@botsci remove @xuanxu as reviewer"
        @responder.match_data = @responder.event_regex.match(msg)
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        @responder.process_message(msg)
      end

      it "should respond to github" do
        expect(@responder).to receive(:respond).with("@xuanxu removed from the reviewers list!")
        @responder.process_message(@msg)
      end

      it "should not remove username if not present in the reviewers list" do
        msg = "@botsci remove @other_user from reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        expect(@responder).to_not receive(:update_issue)
        expect(@responder).to receive(:respond).with("@other_user is not in the reviewers list")
        @responder.process_message(msg)
      end

      it "should accept 'me' as the reviewer to remove" do
        msg = "@botsci remove me from reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        @responder.context[:sender] = "xuanxu"
        expected_new_body = "...Reviewers: <!--reviewers-list-->@arfon<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
        expect(@responder).to receive(:respond).with("@xuanxu removed from the reviewers list!")
        @responder.process_message(msg)
      end

      it "should not remove as assignee if not configured" do
        expect(@responder).to_not receive(:remove_assignee)
        @responder.process_message(@msg)
      end

      it "should remove as assignee if configured" do
        @responder.params[:add_as_assignee] = true
        expect(@responder).to receive(:remove_assignee)
        @responder.process_message(@msg)
      end

      it "should not call Reviewers API if no configured and log error" do
        expect(Faraday).to_not receive(:post)
        expected_error = "Error unassigning @xuanxu from review 3342: Missing configuration values for the API: host's URL and/or API Token"
        expect(@responder.logger).to receive(:warn).with(expected_error)
        @responder.process_message(@msg)
      end

      it "should not call Reviewers API if issue is not a review" do
        @responder.context[:issue_title] = "[PRE REVIEW]: Test"
        @responder.env[:reviewers_host_url] = "https://reviewers.test"
        @responder.env[:reviewers_api_token] = "123456789ABC"

        expect(OJRA::Client).to_not receive(:new)
        expect(Faraday).to_not receive(:post)
        @responder.process_message(@msg)
      end

      it "should call Reviewers API" do
        @responder.env[:reviewers_host_url] = "https://reviewers.test"
        @responder.env[:reviewers_api_token] = "123456789ABC"

        client_double = instance_double(OJRA::Client)
        expect(OJRA::Client).to receive(:new).with("https://reviewers.test", "123456789ABC").and_return(client_double)
        expect(client_double).to receive(:unassign_reviewers).with("@xuanxu", "3342").and_return(true)
        expect(client_double).to receive(:error_msg).and_return(nil)
        expect(@responder.logger).to_not receive(:warn)
        @responder.process_message(@msg)
      end
    end

    describe "No reviewers text" do
      it "should remove 'Pending' when adding first reviewer" do
        msg = "@botsci add @xuanxu to reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        issue_body = "...Reviewers: <!--reviewers-list-->Pending<!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)

        expected_new_body = "...Reviewers: <!--reviewers-list-->@xuanxu<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

        @responder.process_message(msg)
      end

      it "should detect variations of the no reviewers text" do
        msg = "@botsci add @xuanxu to reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        issue_body = "...Reviewers: <!--reviewers-list-->PENDING<!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)

        expected_new_body = "...Reviewers: <!--reviewers-list-->@xuanxu<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

        @responder.process_message(msg)
      end

      it "should add 'Pending' when removing last reviewer" do
        msg = "@botsci remove @xuanxu from reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        issue_body = "...Reviewers: <!--reviewers-list-->@xuanxu<!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)

        expected_new_body = "...Reviewers: <!--reviewers-list-->Pending<!--end-reviewers-list--> ..."
        expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

        @responder.process_message(msg)
      end

      describe "with custom text" do
        before do
          @responder.params = { no_reviewers_text: "No reviewers"}
        end

        it "should work when adding a reviewer" do
          msg = "@botsci add @xuanxu to reviewers"
          @responder.match_data = @responder.event_regex.match(msg)
          issue_body = "...Reviewers: <!--reviewers-list-->No reviewers<!--end-reviewers-list--> ..."
          allow(@responder).to receive(:issue_body).and_return(issue_body)

          expected_new_body = "...Reviewers: <!--reviewers-list-->@xuanxu<!--end-reviewers-list--> ..."
          expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

          @responder.process_message(msg)
        end

        it "should work when removing a reviewer" do
          msg = "@botsci remove @xuanxu from reviewers"
          @responder.match_data = @responder.event_regex.match(msg)
          issue_body = "...Reviewers: <!--reviewers-list-->@xuanxu<!--end-reviewers-list--> ..."
          allow(@responder).to receive(:issue_body).and_return(issue_body)

          expected_new_body = "...Reviewers: <!--reviewers-list-->No reviewers<!--end-reviewers-list--> ..."
          expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

          @responder.process_message(msg)
        end
      end
    end

    describe "labeling" do
      it "should process labeling when adding the first reviewer" do
        msg = "@botsci add @xuanxu to reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        issue_body = "...Reviewers: <!--reviewers-list--><!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)

        expect(@responder).to receive(:process_labeling)
        @responder.process_message(msg)
      end

      it "should process reverse labeling when removing the last reviewer" do
        msg = "@botsci remove @xuanxu from reviewers"
        @responder.match_data = @responder.event_regex.match(msg)
        issue_body = "...Reviewers: <!--reviewers-list-->@xuanxu<!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)

        expect(@responder).to receive(:process_reverse_labeling)
        @responder.process_message(msg)
      end

      it "should not add/remove labels otherwise" do
        issue_body = "...Reviewers: <!--reviewers-list-->@xuanxu, @arfon<!--end-reviewers-list--> ..."
        allow(@responder).to receive(:issue_body).and_return(issue_body)

        msg = "@botsci add @user3 to reviewers"
        @responder.match_data = @responder.event_regex.match(msg)

        expect(@responder).to_not receive(:process_labeling)
        expect(@responder).to_not receive(:process_reverse_labeling)
        @responder.process_message(msg)

        msg = "@botsci remove @xuanxu from reviewers"
        @responder.match_data = @responder.event_regex.match(msg)

        expect(@responder).to_not receive(:process_labeling)
        expect(@responder).to_not receive(:process_reverse_labeling)
        @responder.process_message(msg)
      end
    end
  end

  describe "#add_as_collaborator?" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "is false if value is not a username" do
      expect(@responder.username?("not username value")).to be_falsy
      expect(@responder.add_as_collaborator?("not username value")).to be_falsy
    end

    it "is false if param[:add_as_collaborator] is false" do
      expect(@responder.username?("@username")).to be_truthy
      expect(@responder.params[:add_as_collaborator]).to be_falsy
      expect(@responder.add_as_collaborator?("@username")).to be_falsy
    end

    it "is true if value is username and param[:add_as_collaborator] is true" do
      expect(@responder.username?("@username")).to be_truthy
      @responder.params[:add_as_collaborator] = true
      expect(@responder.add_as_collaborator?("@username")).to be_truthy
    end
  end

  describe "#add_as_assignee?" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, {}) }

    it "is false if value is not a username" do
      expect(@responder.username?("not username value")).to be_falsy
      expect(@responder.add_as_assignee?("not username value")).to be_falsy
    end

    it "is false if param[:add_as_assignee] is false" do
      expect(@responder.username?("@username")).to be_truthy
      expect(@responder.params[:add_as_assignee]).to be_falsy
      expect(@responder.add_as_assignee?("@username")).to be_falsy
    end

    it "is true if value is username and param[:add_as_assignee] is true" do
      expect(@responder.username?("@username")).to be_truthy
      @responder.params[:add_as_assignee] = true
      expect(@responder.add_as_assignee?("@username")).to be_truthy
    end
  end

  describe "documentation" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { sample_value: "@new_reviewer"})
    end

    it "#description should include adding and removing reviewers" do
      expect(@responder.description[0]).to eq("Add to this issue's reviewers list")
      expect(@responder.description[1]).to eq("Remove from this issue's reviewers list")
    end

    it "#example_invocation should use custom sample value if present" do
      expect(@responder.example_invocation[0]).to eq("@botsci add @new_reviewer as reviewer")
      expect(@responder.example_invocation[1]).to eq("@botsci remove @new_reviewer from reviewers")
    end

    it "#example_invocation should have default sample value" do
      @responder.params = {}
      expect(@responder.example_invocation[0]).to eq("@botsci add @username as reviewer")
      expect(@responder.example_invocation[1]).to eq("@botsci remove @username from reviewers")
    end
  end

end
