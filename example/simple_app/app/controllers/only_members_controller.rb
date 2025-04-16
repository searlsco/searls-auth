class OnlyMembersController < ApplicationController
  before_action :require_user

  def show
  end
end
