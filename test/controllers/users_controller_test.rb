require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one) # admin
  end

  test "index" do
    get users_path
    assert_response :success
  end

  test "new" do
    get new_user_path
    assert_response :success
  end

  test "create" do
    assert_difference("User.count") do
      post users_path, params: { user: { name: "New User", email_address: "new@test.com", password: "password", password_confirmation: "password", role: "agent" } }
    end
    assert_redirected_to users_path
  end

  test "agent role cannot access users" do
    sign_in_as users(:two)
    get users_path
    assert_redirected_to root_path
  end
end
