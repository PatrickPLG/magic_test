module MagicTest
  # The browser wizard's endpoints under /__magic_test (mounted only when
  # MagicTest.enabled?). The page is served by the engine; the JSON endpoints
  # talk to the BrowserSession the entry example is blocking in.
  class WizardController < ActionController::Base
    skip_forgery_protection
    layout false

    def page
      response.headers["Cache-Control"] = "no-store"
      render html: WizardBundle.page_html.html_safe
    end

    def script
      response.headers["Cache-Control"] = "no-store"
      render plain: WizardBundle.cached, content_type: "application/javascript"
    end

    def catalogue
      session = wizard or return render(json: {ok: false, error: "no wizard session (run bin/magic new)"})
      render json: session.catalogue_payload
    end

    def state
      session = wizard or return render(json: {status: "idle"})
      render json: session.state_payload
    end

    # preview | preflight | start | cancel
    def command
      session = wizard or return render(json: {ok: false, error: "no wizard session (run bin/magic new)"})
      payload = JSON.parse(request.raw_post.presence || "{}")
      result = session.enqueue(params[:name].to_s, payload)
      render json: result.merge(state: session.state_payload)
    rescue => e
      render json: {ok: false, error: "#{e.class}: #{e.message}"}
    end

    private

    def wizard
      require "magic_test/wizard/browser_session"
      MagicTest::Wizard::BrowserSession.current
    end
  end
end
