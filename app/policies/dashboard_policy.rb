# frozen_string_literal: true

class DashboardPolicy < Struct.new(:user, :dashboard)
  def show? = true
end
