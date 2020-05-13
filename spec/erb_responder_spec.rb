require_relative "./spec_helper.rb"

describe "ERB Responder" do

  subject do
    Responder.new({}, {})
  end

  describe "#respond_template" do
    before { disable_github_calls_for subject }

    it "should respond the rendered named erb template with passed locals" do
      template_name = :help
      locals =  {sender: "buffy", descriptions_and_examples: []}
      template = ERB.new(File.read("#{app.root}/responses/help.erb"))
      expected_response = template.result_with_hash(locals)

      expect(subject).to receive(:respond).once.with(expected_response)
      subject.respond_template(template_name, locals)
    end
  end

end