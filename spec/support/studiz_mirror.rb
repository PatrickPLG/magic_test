# Studiz sets its driver per spec (`before { driven_by :cuprite }`). Under
# FIXTURE_STUDIZ_MIRROR there is no global registration, so specs that must run
# in both configurations call this from their own before block.
module StudizMirrorSupport
  def studiz_driven_by
    driven_by(:cuprite, screen_size: [1200, 800], options: FixtureAppSupport::CUPRITE_OPTIONS.dup)
  end
end

RSpec.configure { |config| config.include StudizMirrorSupport, type: :system }
