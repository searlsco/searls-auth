require "test_helper"

Capybara.register_driver :my_playwright do |app|
  Capybara::Playwright::Driver.new(app,
    browser_type: ENV["PLAYWRIGHT_BROWSER"]&.to_sym || :chromium,
    headless: !!(ENV["CI"] || ENV["PLAYWRIGHT_HEADLESS"]))
end

Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :my_playwright
  self.use_transactional_tests = true

  setup do
    ActiveJob::Base.queue_adapter = :inline
  end

  teardown do
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.deliveries.clear
  end
end
