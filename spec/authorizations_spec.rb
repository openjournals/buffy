require_relative "./spec_helper.rb"

describe "Authorizations" do

  subject do
    settings = Sinatra::IndifferentHash[teams:
      { editors: 11,
        reviewers: 22,
        eics: 33,
        guests: "orgbuffy/guests",
        trusted_people: ["user33", "user42"],
        empty: nil }]
    params = { only: ['editors', 'eics', 'trusted_people'] }
    Responder.new(settings, params)
  end

  describe "#authorized_teams" do
    it "should return authorized team values from the config" do
      subject.params = { only: ['editors', 'guests', 'trusted_people'] }
      expect(subject.authorized_teams).to eq([11, "orgbuffy/guests", ["user33", "user42"]])
    end
  end

  context "#authorized_team_ids" do
    describe "when there is no restrictions via :only param" do
      it "should return nothing" do
        subject.params = {}
        expect(subject.authorized_team_ids).to eq([])
      end
    end

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

    describe "when a team with nil value is received" do
      it "should return nothing" do
        subject.params = { only: ['empty'] }
        expect(subject.authorized_team_ids).to eq([])
      end
    end

    describe "when a team with user handles is received" do
      it "should return nothing" do
        subject.params = { only: ['trusted_people'] }
        expect(subject.authorized_team_ids).to eq([])
      end
    end

    describe "when all kind of teams are received" do
      it "should return ids of named teams" do
        subject.params = { only: ['reviewers', 'guests', 'trusted_people', 'empty'] }
        expect(subject).to receive(:team_id).once.with("orgbuffy/guests").and_return(44)
        expect(subject.authorized_team_ids).to eq([22, 44])
      end
    end
  end

  describe "#authorized_team_names" do
    it "should return names of all authorized teams" do
      expect(subject.authorized_team_names).to eq(['editors', 'eics', 'trusted_people'])
    end
  end

  describe "#authorized_teams_sentence" do
    it "should return a sentence of names of all authorized teams" do
      expect(subject.authorized_teams_sentence).to eq('editors, eics and trusted_people')
    end
  end

  describe "#authorized_users" do
    it "should return users specified in the config" do
      subject.params = { only: ['trusted_people'] }
      expect(subject.authorized_users).to eq(['user33', 'user42'])
    end

    it "should ignore ids or team names" do
      subject.params = { only: ['eics', 'guests', 'trusted_people'] }
      expect(subject.authorized_users).to eq(['user33', 'user42'])
    end
  end

  describe "#user_authorized?" do
    it "should be true if user is authorized" do
      subject.params = { only: ['trusted_people'] }
      expect(subject.user_authorized?('user33')).to be_truthy
    end

    it "should be true if user is in an authorized team" do
      subject.params = { only: ['eics'] }
      expect(subject).to receive(:user_in_authorized_teams?).once.with("user77").and_return(true)
      expect(subject.user_authorized?('user77')).to be_truthy
    end

    it "should be false if user is not authorized" do
      subject.params = { only: ['eics'] }
      expect(subject).to receive(:user_in_authorized_teams?).once.with("user77").and_return(false)
      expect(subject.user_authorized?('user77')).to be_falsy
    end
  end

end