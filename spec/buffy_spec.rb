require_relative "./spec_helper.rb"

describe Buffy do

  subject do
    app = described_class.new!
  end

  describe "initialization" do
    it "should parse the config file" do
      expect(subject.settings.buffy["env"]["bot_github_user"]).to eq("botsci")
      expect(subject.settings.buffy["env"]["gh_access_token"]).to eq("secret-access")
      expect(subject.settings.buffy["env"]["gh_secret_token"]).to eq("secret-token")
      expect(subject.settings.buffy["teams"]["editors"]).to eq(2009411)
      expect(subject.settings.buffy["responders"]["hello"]["only"]).to eq("editors")
      expect(subject.settings.buffy["responders"]["thanks"]["hidden"]).to eq(true)
    end
  end

  describe "#dispatch" do

    before do
      allow(Octokit::Client).to receive(:new).never
    end

    context "when verifying signature" do
      it "should error if secret token is not present" do
        with_secret_token nil do
          post "/dispatch", nil, headers.merge({"HTTP_X_HUB_SIGNATURE" => "sha1=39b8d8"})
        end

        expect(last_response.status).to eq(500)
        expect(last_response.body).to eq("Can't compute signature")
      end

      it "should halt if there is not signature" do
        post "/dispatch", nil, headers.merge({"HTTP_X_HUB_SIGNATURE" => nil})

        expect(last_response.status).to eq(403)
        expect(last_response.body).to eq("Request missing signature")
      end

      it "should halt if signatures don't match" do
        with_secret_token "test_secret_token" do
          post "/dispatch", "{'payload':'test'}", headers.merge({"HTTP_X_HUB_SIGNATURE" => "sha1=39b8d8"})
        end

        expect(last_response.status).to eq(403)
        expect(last_response.body).to eq("Signatures didn't match!")
      end
    end

    context "when parsing GitHub payload" do
      describe "context and message" do
        before do
          @issue_data = { action: "test-action",
                          sender: { login: "reviewer33" },
                          repository: { full_name: "buffyorg/buffyrepo" },
                          issue: { number: "42",
                                   title: "New submission",
                                   body: "Body of the issue!",
                                   user: { login: "author" },
                                   labels: ["astrophysics", "tests"] } }
          @payload = @issue_data.to_json
          @expected_context_data = { action: "test-action",
                                     event: "issues",
                                     issue_id: "42",
                                     issue_title: "New submission",
                                     issue_body: "Body of the issue!",
                                     issue_author: "author",
                                     issue_labels: ["astrophysics", "tests"],
                                     repo: "buffyorg/buffyrepo",
                                     sender: "reviewer33",
                                     event_action: "issues.test-action",
                                     raw_payload: JSON.parse(@payload) }
        end

        it "should be correct on issues events" do
          expected_message = "Body of the issue!"
          expected_context = OpenStruct.new(@expected_context_data)
          expect_any_instance_of(ResponderRegistry).to receive(:respond).once.with(expected_message, expected_context)

          with_secret_token "test_secret_token" do
            post "/dispatch", @payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(@payload), "HTTP_X_GITHUB_EVENT" => "issues"})
          end

          expect(last_response.status).to eq(200)
        end

        it "should be correct on issue_comment events" do
          comment_issue_data = @issue_data.merge({ comment: { id: 123456,
                                                              body: "Body of the comment!",
                                                              created_at: "3/3/2033",
                                                              html_url: "https://buf.fy" } })
          comment_payload = comment_issue_data.to_json
          comment_context = @expected_context_data.merge({ event: "issue_comment",
                                                           event_action: "issue_comment.test-action",
                                                           comment_id: 123456,
                                                           comment_body: "Body of the comment!",
                                                           comment_created_at: "3/3/2033",
                                                           comment_url: "https://buf.fy",
                                                           raw_payload: JSON.parse(comment_payload) })
          expected_context = OpenStruct.new(comment_context)
          expected_message = "Body of the comment!"
          expect_any_instance_of(ResponderRegistry).to receive(:respond).once.with(expected_message, expected_context)

          with_secret_token "test_secret_token" do
            post "/dispatch", comment_payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(comment_payload), "HTTP_X_GITHUB_EVENT" => "issue_comment"})
          end

          expect(last_response.status).to eq(200)
        end
      end

      it "should halt if there are errors parsing payload" do
        wrong_payload = "{'malformed': 'payload}}"
        with_secret_token "test_secret_token" do
          post "/dispatch", wrong_payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(wrong_payload)})
        end

        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq("Malformed request")
      end

      it "should halt if there's no event header" do
        with_secret_token "test_secret_token" do
          payload = {hey: "ho"}.to_json
          post "/dispatch", payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(payload), "HTTP_X_GITHUB_EVENT" => nil})
        end

        expect(last_response.status).to eq(422)
        expect(last_response.body).to eq("No event")
      end

      it "should create context for 'issues' events" do
        with_secret_token "test_secret_token" do
          payload = {hey: "ho"}.to_json
          post "/dispatch", payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(payload), "HTTP_X_GITHUB_EVENT" => "issues"})
        end

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Message processed")
        expect(last_response.body).not_to eq("Event discarded")
      end

      it "should create context for 'issue_comment' events" do
        with_secret_token "test_secret_token" do
          payload = {hey: "ho"}.to_json
          post "/dispatch", payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(payload), "HTTP_X_GITHUB_EVENT" => "issue_comment"})
        end

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Message processed")
        expect(last_response.body).not_to eq("Event discarded")
      end

      it "should discard issue_comment events if created by buffy" do
        with_secret_token "test_secret_token" do
          payload = {sender: { login: "botsci" } }.to_json
          post "/dispatch", payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(payload), "HTTP_X_GITHUB_EVENT" => "issue_comment"})
        end

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Event origin discarded")
      end

      it "should not discard issue events if created by buffy" do
        with_secret_token "test_secret_token" do
          payload = {sender: { login: "botsci" } }.to_json
          post "/dispatch", payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(payload), "HTTP_X_GITHUB_EVENT" => "issues"})
        end

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Message processed")
      end

      it "should discard other events" do
        with_secret_token "test_secret_token" do
          payload = {hey: "ho"}.to_json
          post "/dispatch", payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(payload), "HTTP_X_GITHUB_EVENT" => "page_build"})
        end
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Event discarded")
      end
    end
  end

  describe "#status" do
    it "should respond bot name and environment" do
      get "/status"

      expect(last_response).to be_ok
      expect(last_response.body).to include("botsci in test: up and running!")
    end
  end
end
