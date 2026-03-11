require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "validates presence of name" do
    user = User.new(email_address: "x@x.com", password: "password", name: "")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "role enum" do
    assert users(:one).admin?
    assert users(:two).agent?
  end
end
