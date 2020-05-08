require_relative "./spec_helper.rb"

describe Buffy do

  subject do
    app = described_class.new!
  end

  describe "initialization" do
    it "should parse the config file" do
      expect(subject.settings.buffy["bot_github_user"]).to eq("botsci")
      expect(subject.settings.buffy["gh_access_token"]).to eq("secret-access")
      expect(subject.settings.buffy["gh_secret_token"]).to eq("secret-token")
      expect(subject.settings.buffy["teams"]["editors"]).to eq(2009411)
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
        with_secret_token 'test_secret_token' do
          post "/dispatch", "{'payload':'test'}", headers.merge({"HTTP_X_HUB_SIGNATURE" => "sha1=39b8d8"})
        end

        expect(last_response.status).to eq(403)
        expect(last_response.body).to eq("Signatures didn't match!")
      end
    end

    context "when parsing GitHub payload" do
      it "should halt if there are errors parsing payload" do
        wrong_payload = "{'malformed': 'payload}}"
        with_secret_token 'test_secret_token' do
          post "/dispatch", wrong_payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(wrong_payload)})
        end

        expect(last_response.status).to eq(400)
        expect(last_response.body).to eq("Malformed request")
      end

      it "should halt if there's no event header" do
        with_secret_token 'test_secret_token' do
          post "/dispatch", "{}", headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for("{}"), 'HTTP_X_GITHUB_EVENT' => nil})
        end

        expect(last_response.status).to eq(422)
        expect(last_response.body).to eq("No event")
      end

      it "should create context for 'issues' events" do
        with_secret_token 'test_secret_token' do
          post "/dispatch", "{}", headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for("{}"), 'HTTP_X_GITHUB_EVENT' => 'issues'})
        end

        expect(last_response.status).to eq(200)
        expect(last_response.body).not_to eq("Event discarded")
      end

      it "should create context for 'issue_comment' events" do
        with_secret_token 'test_secret_token' do
          post "/dispatch", "{}", headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for("{}"), 'HTTP_X_GITHUB_EVENT' => 'issue_comment'})
        end

        expect(last_response.status).to eq(200)
        expect(last_response.body).not_to eq("Event discarded")
      end

      it "should discard event if created by buffy" do
        with_secret_token 'test_secret_token' do
          payload = '{"sender":{"login":"botsci"}}'
          post "/dispatch", payload, headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for(payload), 'HTTP_X_GITHUB_EVENT' => 'issue_comment'})
        end

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Event origin discarded")
      end

      it "should discard other events" do
        with_secret_token 'test_secret_token' do
          post "/dispatch", "{}", headers.merge({"HTTP_X_HUB_SIGNATURE" => signature_for("{}"), 'HTTP_X_GITHUB_EVENT' => 'page_build'})
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
