class V1UnavailableController < ApplicationController
  def show
    head :not_found
  end
end
