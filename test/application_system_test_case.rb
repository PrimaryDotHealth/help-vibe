require "test_helper"
require "capybara/cuprite"

# Cuprite drives Chrome over the DevTools protocol (no chromedriver). With
# Selenium + chromedriver on Chrome 156/macOS, real clicks stopped reaching the
# page after a few idle seconds, which broke the autosave-then-publish test.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, screen_size: [ 1440, 1000 ], options: { headless: true, process_timeout: 20, timeout: 10 }
end
