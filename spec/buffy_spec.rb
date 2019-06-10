require File.expand_path "../spec_helper.rb", __FILE__
require File.expand_path "../support/fake_github.rb", __FILE__

describe Buffy do
  let(:issue_opened_json) { json_fixture('issue-opened.json') }

  subject do
    app = described_class.new!
  end

  describe "#dispatch" do
    context "with junk params" do
      before do
        allow(Octokit::Client).to receive(:new).never
        post "/dispatch", "foo", {"CONTENT_TYPE" => "application/json"}
      end

      it "should halt" do
        expect(last_response.status).to eq(500)
      end
    end

    context "with empty params" do
      before do
        allow(Octokit::Client).to receive(:new).never
        post "/dispatch", nil, {"CONTENT_TYPE" => "application/json"}
      end

      it "should halt" do
        expect(last_response.status).to eq(500)
      end
    end

    context "with issue opened" do
      before do
        allow(WelcomeResponder).to receive(:new).once.and_call_original
        allow(Octokit::Client).to receive(:new).once.and_return(@github)
        expect(@github).to receive(:add_comment).once.with("ropensci/software-reviews-testing", 89, "Hi!")
        post "/dispatch", issue_opened_json, {"CONTENT_TYPE" => "application/json", "X-GitHub-Event" => "issues"}
      end

      it "should" do
        expect(last_response.status).to eq(200)
      end
    end
  end
end
