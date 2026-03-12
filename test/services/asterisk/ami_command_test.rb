require "test_helper"

class Asterisk::AmiCommandTest < ActiveSupport::TestCase
  test "reload returns false on connection error" do
    original_host = Asterisk::AmiCommand::HOST
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, "127.0.0.254")

    result = Asterisk::AmiCommand.new.reload("pjsip")
    assert_equal false, result
  ensure
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, original_host)
  end

  test "queue_add returns false on connection error" do
    original_host = Asterisk::AmiCommand::HOST
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, "127.0.0.254")

    result = Asterisk::AmiCommand.new.queue_add("support", "PJSIP/1001")
    assert_equal false, result
  ensure
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, original_host)
  end

  test "queue_remove returns false on connection error" do
    original_host = Asterisk::AmiCommand::HOST
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, "127.0.0.254")

    result = Asterisk::AmiCommand.new.queue_remove("support", "PJSIP/1001")
    assert_equal false, result
  ensure
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, original_host)
  end

  test "queue_pause returns false on connection error" do
    original_host = Asterisk::AmiCommand::HOST
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, "127.0.0.254")

    result = Asterisk::AmiCommand.new.queue_pause("support", "PJSIP/1001", paused: true)
    assert_equal false, result
  ensure
    Asterisk::AmiCommand.send(:remove_const, :HOST)
    Asterisk::AmiCommand.const_set(:HOST, original_host)
  end
end
