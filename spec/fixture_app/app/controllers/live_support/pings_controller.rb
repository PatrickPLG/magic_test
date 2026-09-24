module LiveSupport
  # Emulates the Studiz live-support widget's background traffic (ActionCable +
  # polling XHR) so the recorder can be proven to ignore it.
  class PingsController < ApplicationController
    skip_before_action :authenticate_from_auth_token_cookie

    def ping
      render json: {ok: true, at: Time.now.to_f}
    end

    def ping_post
      render json: {ok: true}
    end
  end
end
