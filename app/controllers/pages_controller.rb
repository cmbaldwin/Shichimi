class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[science install]

  def install; end

  def science
    @formats = WorkoutFormat.all
    @references = YAML.load_file(Rails.root.join("config/catalog/references.yml"))
  end
end
