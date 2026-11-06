class StatsController < ApplicationController
  def show
    @stats = Stats.new(current_user)
  end
end
