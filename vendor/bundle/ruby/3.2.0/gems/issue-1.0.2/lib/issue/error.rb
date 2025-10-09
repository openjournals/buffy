module Issue
  class Error
    attr :status
    attr :message

    # Initialize Issue::Error object with:
    # status: html status code
    # msg: message to send back in response
    def initialize(status, msg)
      @status = status
      @message = msg
    end

  end
end