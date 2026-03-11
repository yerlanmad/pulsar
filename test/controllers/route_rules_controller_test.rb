require "test_helper"

class RouteRulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @route = route_rules(:one)
  end

  test "index" do
    get route_rules_path
    assert_response :success
  end

  test "new" do
    get new_route_rule_path
    assert_response :success
  end

  test "create" do
    assert_difference("RouteRule.count") do
      post route_rules_path, params: { route_rule: { name: "New Route", pattern: "+4400*", queue_config_id: queue_configs(:one).id, position: 5 } }
    end
    assert_redirected_to route_rules_path
  end

  test "update" do
    patch route_rule_path(@route), params: { route_rule: { name: "Updated" } }
    assert_redirected_to route_rules_path
    assert_equal "Updated", @route.reload.name
  end

  test "destroy" do
    assert_difference("RouteRule.count", -1) do
      delete route_rule_path(@route)
    end
    assert_redirected_to route_rules_path
  end
end
