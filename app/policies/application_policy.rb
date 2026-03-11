# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = user.admin? || user.supervisor?
  def show? = user.admin? || user.supervisor?
  def create? = user.admin?
  def new? = create?
  def update? = user.admin?
  def edit? = update?
  def destroy? = user.admin?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = scope.all

    private

    attr_reader :user, :scope
  end
end
