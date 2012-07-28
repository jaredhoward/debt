class MainController < ApplicationController

  def show
    @reduction_calc = ReductionCalculator.new(ReductionCalculator.debt_hash)
  end

  def edit
  end

  def update
  end

end
