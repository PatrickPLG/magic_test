module MagicTest
  # Endpoints under /__magic_test, mounted only when MagicTest.enabled?.
  # Deliberately inherits from ActionController::Base, not the host app's
  # ApplicationController (no auth filters, no locale hooks).
  class RecorderController < ActionController::Base
    skip_forgery_protection
    layout false

    def script
      response.headers["Cache-Control"] = "no-store"
      render plain: RecorderBundle.cached, content_type: "application/javascript"
    end

    # Named `bootstrap` because `config` is already ActionController::Base#config.
    def bootstrap
      render json: session_payload(:config)
    end

    def state
      render json: session_payload(:state)
    end

    def events
      session = MagicTest.session
      return render(json: {ok: false, error: "no session", acked: []}, status: 200) unless session
      payload = JSON.parse(request.raw_post.presence || "{}")
      acked = session.receive_events(Array(payload["events"]))
      render json: {ok: true, acked: acked, state: session.state_payload}
    end

    def commands
      session = MagicTest.session
      return render(json: {ok: false, error: "no session"}) unless session
      payload = JSON.parse(request.raw_post.presence || "{}")
      result = session.enqueue_command(payload["command"].to_s, payload.except("command"))
      render json: result.merge(state: session.state_payload)
    rescue => e
      render json: {ok: false, error: "#{e.class}: #{e.message}"}
    end

    private

    def session_payload(kind)
      session = MagicTest.session
      return {"status" => "idle", "enabled" => MagicTest.enabled?} unless session
      (kind == :config) ? session.config_payload : session.state_payload
    end
  end
end
