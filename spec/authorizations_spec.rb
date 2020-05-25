require_relative "./spec_helper.rb"

describe "Authorizations" do

  subject do
    settings = Sinatra::IndifferentHash[teams: { editors: 11, reviewers: 22, eics: 33, guests: "orgbuffy/guests" }]
    params = { only: ['editors', 'eics'] }
    Responder.new(settings, params)
  end

  context "#authorized_team_ids" do
    describe "when ids received" do
      it "should return ids of all authorized team" do
        expect(subject.authorized_team_ids).to eq([11, 33])
      end
    end

    describe "when team names received" do
      it "should return ids of all authorized team" do
        subject.params = { only: ['guests'] }
        expect(subject).to receive(:team_id).once.with("orgbuffy/guests").and_return(44)
        expect(subject.authorized_team_ids).to eq([44])
      end
    end

    describe "when a mix of ids and names are received" do
      it "should return ids of all authorized team" do
        subject.params = { only: ['editors', 'guests'] }
        expect(subject).to receive(:team_id).once.with("orgbuffy/guests").and_return(44)
        expect(subject.authorized_team_ids).to eq([11, 44])
      end
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