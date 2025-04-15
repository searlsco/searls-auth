module Searls
  module Auth
    class BaseMailer < ApplicationMailer # TODO should this be ActionMailer::Base? Trade-offs?
      helper Searls::Auth::ApplicationHelper
      include Searls::Auth::ApplicationHelper
    end
  end
end
