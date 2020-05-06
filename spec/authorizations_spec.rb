require_relative "./spec_helper.rb"

describe "Authorizations" do

  subject do
    settings = { teams: { 'editors' => 11, reviewers: 22, eics: 33} }
    params ={ only: ['editors', 'eics'] }
    Responder.new(settings, params)
  end

  describe "#authorized_team_ids" do
    it "should return ids of all authorized teams" do
      expect(subject.authorized_team_ids(subject.params)).to eq([11, 33])
    end
  end


end