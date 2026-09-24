module MagicTest
  # Backwards-compatible surface of the original gem: `magic_test`, `flush`
  # and `ok`. `magic_test` lives in Helpers (always available); `flush`/`ok`
  # are what power users type in the optional Pry console.
  module Support
    include Helpers

    # Writes the pending steps to the spec (same as the toolbar's Save).
    def flush
      session = MagicTest.session or raise MagicTest::Error, "no recording session (call magic_test first)"
      result = session.save!
      puts result[:message]
      result[:ok]
    end

    # Writes the last line typed into the console above the magic_test call.
    def ok
      session = MagicTest.session or raise MagicTest::Error, "no recording session (call magic_test first)"
      code = MagicTest::Console.last_input
      raise MagicTest::Error, "ok: nothing in the console history to save" if code.blank?
      session.write_raw_lines!(code.lines.map(&:chomp))
      puts "(wrote #{code.lines.size} line(s) to #{session.call_site.path})"
      true
    end
  end
end
