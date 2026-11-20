require_relative "./spec_helper.rb"

describe GitHubWebhookFilter do
  describe ".space_trim_message" do
    def space_trim(text)
      described_class.space_trim_message(text)
    end

    it "should return nil for nil" do
      expect(space_trim(nil)).to be_nil
    end

    it "should leave a well-formed command untouched" do
      expect(space_trim("@botsci assign @arfon as reviewer")).to eq("@botsci assign @arfon as reviewer")
    end

    it "should collapse repeated spaces" do
      expect(space_trim("@botsci assign @arfon  as reviewer")).to eq("@botsci assign @arfon as reviewer")
      expect(space_trim("@botsci   set due date for @arfon    to 2026-12-09")).to eq("@botsci set due date for @arfon to 2026-12-09")
    end

    it "should convert tabs and non-breaking spaces to a single space" do
      expect(space_trim("@botsci\tassign @arfon \t as reviewer")).to eq("@botsci assign @arfon as reviewer")
      expect(space_trim("@botsci assign @arfon as reviewer")).to eq("@botsci assign @arfon as reviewer")
    end

    it "should remove zero-width characters" do
      expect(space_trim("@botsci​ assign﻿ @arfon as‍ reviewer")).to eq("@botsci assign @arfon as reviewer")
    end

    it "should strip leading and trailing whitespace" do
      expect(space_trim("  @botsci help \n")).to eq("@botsci help")
    end

    it "should keep line breaks but trim spaces around them" do
      expect(space_trim("@botsci help  \r\n  thanks!")).to eq("@botsci help\nthanks!")
      expect(space_trim("line one\n\nline two")).to eq("line one\n\nline two")
    end
  end
end
