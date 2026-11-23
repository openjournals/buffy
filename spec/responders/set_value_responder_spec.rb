require_relative "../spec_helper.rb"

describe SetValueResponder do

  subject do
    described_class
  end

  describe "listening" do
    before { @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "version" }) }

    it "should listen to new comments" do
      expect(@responder.event_action).to eq("issue_comment.created")
    end

    it "should define regex" do
      expect(@responder.event_regex).to match("@botsci set v1.0.3-beta as version")
      expect(@responder.event_regex).to match("@botsci set v1.0.3-beta as version.")
      expect(@responder.event_regex).to match("@botsci set 2.345 as version   \r\n")
      expect(@responder.event_regex).to match("@botsci set 2.345 as version   \r\n more")
      expect(@responder.event_regex).to_not match("@botsci set v12.0 as editor")
      expect(@responder.event_regex).to_not match("@botsci set v1.0.3-beta as version now")
    end
  end

  describe "#process_message" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "version" })
      disable_github_calls_for(@responder)

      @msg = "@botsci set v0.0.33-alpha as version"
      @responder.match_data = @responder.event_regex.match(@msg)

      issue_body = "...Latest Version: <!--version-->Pending<!--end-version--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    it "should update value in the body of the issue" do
      expected_new_body = "...Latest Version: <!--version-->v0.0.33-alpha<!--end-version--> ..."
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
      @responder.process_message(@msg)
    end

    it "should respond to github" do
      expect(@responder).to receive(:respond).with("Done! version is now v0.0.33-alpha")
      @responder.process_message(@msg)
    end

    it "should process labels" do
      expect(@responder).to receive(:process_labeling)
      expect(@responder).to_not receive(:process_reverse_labeling)
      @responder.process_message(@msg)
    end

    it "should process external call" do
      @responder.context = OpenStruct.new(issue_id: 15,
                                          issue_author: "opener",
                                          repo: "tests",
                                          sender: "rev33")
      external_call = { url: "https://theoj.org" ,method: "post", query_params: { secret: "A1234567890Z" }, silent: true}
      @responder.params = { external_call: external_call }
      expected_locals = @responder.locals.merge({new_value: "v0.0.33-alpha"})
      expect(@responder).to receive(:process_external_service).with(external_call, expected_locals)

      @responder.process_message(@msg)
    end

    it "should not process external call" do
      expect(@responder).to_not receive(:process_external_service)
      @responder.process_message(@msg)
    end
  end

  describe "using an alias" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "version", aliased_as: "release-number" })
      disable_github_calls_for(@responder)

      issue_body = "...Latest Version: <!--version-->Pending<!--end-version--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    it "should accept command using alias" do
      msg = "@botsci set v0.0.33-alpha as release-number"
      expect(@responder.event_regex).to match(msg)
      @responder.match_data = @responder.event_regex.match(msg)

      expected_new_body = "...Latest Version: <!--version-->v0.0.33-alpha<!--end-version--> ..."
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })
      expect(@responder).to receive(:respond).with("Done! release-number is now v0.0.33-alpha")
      expect(@responder).to receive(:process_labeling)
      expect(@responder).to_not receive(:process_reverse_labeling)

      @responder.process_message(msg)
    end

    it "should not accept command using name" do
      expect(@responder.event_regex).to_not match("@botsci set v0.0.33-alpha as version")
    end
  end

  describe "with config option: if_missing" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "version" })
      disable_github_calls_for(@responder)

      @msg = "@botsci set v0.0.33-beta as version"
      @responder.match_data = @responder.event_regex.match(@msg)

      issue_body = "... text ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)
    end

    it "should append" do
      @responder.params[:if_missing] = "append"

      expected_new_body = "... text ...\n**Version:** <!--version-->v0.0.33-beta<!--end-version-->"
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

      expect(@responder).to receive(:respond).with("Done! version is now v0.0.33-beta")
      @responder.process_message(@msg)
    end

    it "should prepend" do
      @responder.params[:if_missing] = "prepend"

      expected_new_body = "**Version:** <!--version-->v0.0.33-beta<!--end-version-->\n... text ..."
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

      expect(@responder).to receive(:respond).with("Done! version is now v0.0.33-beta")
      @responder.process_message(@msg)
    end

    it "should error" do
      @responder.params[:if_missing] = "error"

      expect(@responder).to_not receive(:update_issue)
      expect(@responder).to receive(:respond).with("Error: `version` not found in the issue's body")
      @responder.process_message(@msg)
    end

    it "should use custom heading" do
      @responder.params[:if_missing] = "append"
      @responder.params[:heading] = "Released version"

      expected_new_body = "... text ...\n**Released version:** <!--version-->v0.0.33-beta<!--end-version-->"
      expect(@responder).to receive(:update_issue).with({ body: expected_new_body })

      expect(@responder).to receive(:respond).with("Done! version is now v0.0.33-beta")
      @responder.process_message(@msg)
    end
  end

  describe "with config option: template_file" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "version", if_missing: "error", template_file: "version_changed.md"})
      @responder.context = OpenStruct.new(issue_id: 5, issue_author: "opener", issue_title: "Title!", repo: "openjournals/buffy", sender: "user33")
      disable_github_calls_for(@responder)
      @msg = "@botsci set v0.0.33-alpha as version"
      @responder.match_data = @responder.event_regex.match(@msg)
    end

    it "should reply with the template" do
      issue_body = "...Latest Version: <!--version-->Pending<!--end-version--> ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)

      expected_locals = { name: "version",
                          value: "v0.0.33-alpha",
                          bot_name: "botsci",
                          issue_author: "opener",
                          issue_title: "Title!",
                          issue_id: 5,
                          match_data_1: "v0.0.33-alpha",
                          repo: "openjournals/buffy",
                          sender: "user33" }

      expect(@responder).to receive(:respond_external_template).with("version_changed.md", expected_locals)
      expect(@responder).to_not receive(:respond)
      @responder.process_message(@msg)
    end

    it "should not use template if error" do
      issue_body = "... text ..."
      allow(@responder).to receive(:issue_body).and_return(issue_body)

      expect(@responder).to_not receive(:update_issue)
      expect(@responder).to_not receive(:respond_external_template)
      expect(@responder).to receive(:respond).with("Error: `version` not found in the issue's body")
      @responder.process_message(@msg)
    end
  end

  describe "with config option: run_responder" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "archive" })
      disable_github_calls_for(@responder)
      @responder.context = OpenStruct.new(issue_id: 15, repo: "tests", sender: "rev33")
      @msg = "@botsci set 10.5281/zenodo.123 as archive"
      @responder.match_data = @responder.event_regex.match(@msg)
      allow(@responder).to receive(:issue_body).and_return("Archive: <!--archive-->Pending<!--end-archive-->")
    end

    it "should run the other responder with the new value in its message" do
      @responder.params = { name: "archive",
                            run_responder: { responder_key: "check_zenodo_doi", message: "@{{bot_name}} check zenodo doi {{value}}" } }

      expect(@responder).to receive(:process_other_responder).with({ responder_key: "check_zenodo_doi",
                                                                     message: "@botsci check zenodo doi 10.5281/zenodo.123" })
      @responder.process_message(@msg)
    end

    it "should not change the configured message" do
      run_responder = { responder_key: "check_zenodo_doi", message: "check {{value}}" }
      @responder.params = { name: "archive", run_responder: run_responder }
      allow(@responder).to receive(:process_other_responder)

      @responder.process_message(@msg)
      expect(run_responder[:message]).to eq("check {{value}}")
    end

    it "should run other responders without a message" do
      @responder.params = { name: "archive", run_responder: { responder_key: "hello" } }
      expect(@responder).to receive(:process_other_responder).with({ responder_key: "hello" })
      @responder.process_message(@msg)
    end

    it "should run a list of other responders" do
      @responder.params = { name: "archive",
                            run_responder: [{ zenodo: { responder_key: "check_zenodo_doi", message: "check {{value}}" } },
                                            { greeting: { responder_key: "hello" } }] }

      expect(@responder).to receive(:process_other_responder).with({ responder_key: "check_zenodo_doi", message: "check 10.5281/zenodo.123" }).ordered
      expect(@responder).to receive(:process_other_responder).with({ responder_key: "hello" }).ordered
      @responder.process_message(@msg)
    end

    it "should reply before running the other responders" do
      @responder.params = { name: "archive", run_responder: { responder_key: "hello" } }
      expect(@responder).to receive(:respond).with("Done! archive is now 10.5281/zenodo.123").ordered
      expect(@responder).to receive(:process_other_responder).ordered
      @responder.process_message(@msg)
    end

    it "should not run other responders if the value couldn't be set" do
      @responder.params = { name: "archive", if_missing: "error", run_responder: { responder_key: "hello" } }
      allow(@responder).to receive(:issue_body).and_return("No archive here")
      expect(@responder).to_not receive(:process_other_responder)
      @responder.process_message(@msg)
    end

    it "should not run other responders if not configured" do
      expect(@responder).to_not receive(:process_other_responder)
      @responder.process_message(@msg)
    end
  end

  describe "checking the Zenodo DOI after setting the archive" do
    let(:settings) do
      Sinatra::IndifferentHash[
        env: { bot_github_user: "botsci" },
        responders: {
          set_value: [{ archive: { run_responder: { responder_key: "check_zenodo_doi",
                                                    message: "@{{bot_name}} check zenodo doi {{value}}" } } }],
          check_zenodo_doi: nil
        }
      ]
    end

    before do
      @responder = ResponderRegistry.get_responder(settings, "set_value", "archive")
      @responder.context = OpenStruct.new(issue_id: 15, repo: "tests", sender: "editor", comment_id: 111)
      allow(@responder).to receive(:issue_body).and_return("Archive: <!--archive-->Pending<!--end-archive-->")
      allow_any_instance_of(CheckZenodoDoiResponder).to receive(:github_client).and_return(double(create_issue_comment_reaction: true))
      disable_github_calls_for(@responder)
    end

    def set_archive(value)
      msg = "@botsci set #{value} as archive"
      @responder.match_data = @responder.event_regex.match(msg)
      @responder.process_message(msg)
    end

    it "checks a Zenodo DOI" do
      expect(@responder).to receive(:respond).with("Done! archive is now 10.5281/zenodo.11164917")
      expect(ZenodoDoiWorker).to receive(:perform_async).with(hash_including("bot_name" => "botsci"), "10.5281/zenodo.11164917")
      set_archive("10.5281/zenodo.11164917")
    end

    it "checks a Zenodo DOI written as a doi.org link" do
      expect(ZenodoDoiWorker).to receive(:perform_async).with(anything, "https://doi.org/10.5281/zenodo.11164917")
      set_archive("https://doi.org/10.5281/zenodo.11164917")
    end

    ["10.21105/joss.01234", "10.6084/m9.figshare.123", "https://osf.io/abcde", "some text"].each do |value|
      it "says nothing more about #{value.inspect}, which isn't a Zenodo DOI" do
        expect(@responder).to receive(:respond).with("Done! archive is now #{value}").once
        expect_any_instance_of(CheckZenodoDoiResponder).to_not receive(:respond)
        expect_any_instance_of(CheckZenodoDoiResponder).to_not receive(:react_to_comment)
        expect(ZenodoDoiWorker).to_not receive(:perform_async)
        set_archive(value)
      end
    end
  end

  describe "misconfiguration" do
    it "should raise error if name is missing from config" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, {})
      }.to raise_error "Configuration Error in SetValueResponder: No value for name."
    end

    it "should raise error if name is empty" do
      expect {
        @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "    " })
      }.to raise_error "Configuration Error in SetValueResponder: No value for name."
    end
  end

  describe "documentation" do
    before do
      @responder = subject.new({env: {bot_github_user: "botsci"}}, { name: "archive", sample_value: "10.21105/joss.12345"})
    end

    it "#description should include name" do
      expect(@responder.description).to eq("Set a value for archive")
    end

    it "#example_invocation should use custom sample value if present" do
      expect(@responder.example_invocation).to eq("@botsci set 10.21105/joss.12345 as archive")
    end

    it "#example_invocation should have default sample value" do
      @responder.params = { name: "archive" }
      expect(@responder.example_invocation).to eq("@botsci set xxxxx as archive")
    end
  end
end
