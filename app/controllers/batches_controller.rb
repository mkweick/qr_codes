class BatchesController < ApplicationController

  def create
    @batch = Batch.new
  end
end