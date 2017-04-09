require "helper"

class TestClient < Test::Unit::TestCase
  def zulip_site
    URI.parse("https://zulip.example.com/")
  end

  def zulip_api(name)
    (zulip_site + "/api/v1/" + name).to_s
  end

  setup do
    @client = Zulip::Client.new(site: zulip_site.to_s,
                                username: "test",
                                api_key: "test_token")
  end

  sub_test_case "#send_message" do
    test "stream" do
      body = {
        "type" => "stream",
        "to" => "general",
        "subject" => "test",
        "content" => "test"
      }
      stub_request(:post, zulip_api("messages"))
        .with(body: body)
        .to_return(status: 200, body: JSON.generate("msg" => "", "result" => "success", "id" => 89))
      response = @client.send_message(type: :stream,
                                      to: "general",
                                      subject: "test",
                                      content: "test")
      assert_true(response.success?)
      assert_equal({ "msg" => "", "result" => "success", "id" => 89 }, JSON.parse(response.body))
    end

    test "private message" do
      body = {
        "type" => "private",
        "to" => JSON.generate(["test1@zulip.example.com", "test2@zulip.example.com"]),
        "content" => "test"
      }
      stub_request(:post, zulip_api("messages"))
        .with(body: body)
        .to_return(status: 200, body: JSON.generate("msg" => "", "result" => "success", "id" => 89))
      response = @client.send_message(type: :private,
                                      to: ["test1@zulip.example.com", "test2@zulip.example.com"],
                                      content: "test")
      assert_true(response.success?)
      assert_equal({ "msg" => "", "result" => "success", "id" => 89 }, JSON.parse(response.body))
    end
  end

  sub_test_case "#register" do
    test "no arguments" do
      response_body = %q({"msg":"","max_message_id":-1,"last_event_id":-1,"result":"success","queue_id":"1491023319:1"})
      stub_request(:post, zulip_api("register"))
        .with(body: "")
        .to_return(status: 200, body: response_body)
      queue_id, last_event_id = @client.register(event_types: [])
      assert_equal("1491023319:1", queue_id)
      assert_equal(-1, last_event_id)
    end

    data("message" => ["message"],
         "multiple" => ["message", "subscriptions"])
    test "succeeded" do |event_types|
      response_body = %q({"msg":"","max_message_id":-1,"last_event_id":-1,"result":"success","queue_id":"1491023319:1"})
      stub_request(:post, zulip_api("register"))
        .with(body: { "event_types" => JSON.generate(event_types) })
        .to_return(status: 200, body: response_body)
      queue_id, last_event_id = @client.register(event_types: event_types)
      assert_equal("1491023319:1", queue_id)
      assert_equal(-1, last_event_id)
    end
  end

  sub_test_case "#unregister" do
    test "succeeded" do
      stub_request(:delete, zulip_api("events"))
        .with(body: "queue_id=1491023319%3A2")
        .to_return(status: 200, body: %q({"msg":"","result":"success"}))
      assert_true(@client.unregister("1491023319:2"))
    end

    test "no such queue_id" do
      stub_request(:delete, zulip_api("events"))
        .with(body: "queue_id=1491023319%3A2")
        .to_return(status: 400, body: %q({"msg":"Bad event queue id: 1491023319:2","result":"error"}))
      ex = assert_raise(Zulip::ResponseError) do
        @client.unregister("1491023319:2")
      end
      assert_equal("Bad event queue id: 1491023319:2", ex.message)
    end
  end

  sub_test_case "#each_event" do
    test "no arguments" do
      pend
    end

    test "specified events" do
      pend
    end

    test "narrow stream" do
      pend
    end
  end

  sub_test_case "#each_message" do
    test "no arguments" do
      pend
    end

    test "narrow stream" do
      pend
    end
  end
end
