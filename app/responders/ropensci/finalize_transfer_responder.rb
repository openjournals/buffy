module Ropensci
  class FinalizeTransferResponder < Responder

    keyname :ropensci_finalize_transfer

    def define_listening
      @event_action = "issue_comment.created"
      @event_regex = /\A@#{bot_name} (finalize|finalise) transfer of (\w+[\w\.-]*\w+)?\.?\s*\z/i
    end

    def process_message(message)
      return unless verify_package
      Ropensci::ApprovedPackageWorker.perform_async("finalize_transfer", serializable(params), serializable(locals), serializable({ package_name: @package_name, package_author: @package_author }))
    end

    def verify_package
      @package_name = match_data[2].to_s.strip
      if @package_name.empty?
        respond("Could not finalize transfer: Please, specify the name of the package (should match the name of the team at the rOpenSci org)")
        return false
      end

      @package_author = context.issue_author.to_s.strip
      if @package_author.empty?
        respond("Could not finalize transfer: Could not identify package author")
        return false
      end
      true
    end

    def default_description
      "Adds package's repo to the rOpenSci team. This command should be issued after approval and transfer of the package."
    end

    def default_example_invocation
      "@#{@bot_name} finalize transfer of package-name"
    end
  end
end
