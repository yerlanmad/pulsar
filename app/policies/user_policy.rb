# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index? = user.admin?
  def show? = user.admin?
  def create? = user.admin?
  def update? = user.admin?
  def destroy? = user.admin? && record != user
end
