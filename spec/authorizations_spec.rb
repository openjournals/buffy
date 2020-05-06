require_relative "./spec_helper.rb"

describe "Authorizations" do

  subject do
    settings = Sinatra::IndifferentHash[teams: { editors: 11, reviewers: 22, eics: 33 }]
    params ={ only: ['editors', 'eics'] }
    Responder.new(settings, params)
  end

  describe "#authorized_team_ids" do
    it "should return ids of all authorized teams" do
      expect(subject.authorized_team_ids).to eq([11, 33])
    end
  end

  describe "#authorized_team_names" do
    it "should return names of all authorized teams" do
      expect(subject.authorized_team_names).to eq(['editors', 'eics'])
    end
  end

  describe "#authorized_teams_sentence" do
    it "should return a sentence of names of all authorized teams" do
      expect(subject.authorized_teams_sentence).to eq('editors and eics')
    end
  end

end