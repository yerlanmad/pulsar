# frozen_string_literal: true

class RecordingPolicy < ApplicationPolicy
  def index? = true
  def show? = true
end
