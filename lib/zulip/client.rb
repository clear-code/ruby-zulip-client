require "json"
require "uri"
require "faraday"
require "typhoeus"
require "typhoeus/adapters/faraday"

require "zulip/error"

Faraday.default_adapter = :typhoeus

module Zulip
  class Client
    attr_accessor :debug

    def initialize(site:, username:, api_key:, **options)
      @site = URI.parse(site)
      @connection = Faraday.new(@site.to_s, options) do |faraday|
        faraday.adapter Faraday.default_adapter
        yield faraday if block_given?
      end
      @connection.basic_auth(username, api_key)
      @debug = false
    end

    def send_message(type: :stream, to: "general", subject: "", content: "")
      @connection.post do |request|
        request.url("/api/v1/messages")
        params = { "type" => type.to_s }
        case type
        when :private
          params["to"] = JSON.generate(Array(to))
        when :stream
          params["to"] = to
          params["subject"] = subject
        end
        params["content"] = content
        request.body = params
      end
    end

    def register(event_types: [], narrow: [])
      response = @connection.post do |request|
        request.url("/api/v1/register")
        params = {}
        params["event_types"] = JSON.generate(event_types) unless event_types.empty?
        params["narrow"] = JSON.generate(narrow) unless narrow.empty?
        request.body = params
      end
      if response.success?
        res = JSON.parse(response.body, symbolize_names: true)
        [res[:queue_id], res[:last_event_id]]
      else
        raise Zulip::ResponseError, reqponse.reason_phrase
      end
    end

    def unregister(queue_id)
      response = @connection.delete do |request|
        request.url("/api/v1/events")
        request.body = { "queue_id" => queue_id }
      end
      if response.success?
        JSON.parse(response.body, symbolize_names: true)[:result] == "success"
      else
        raise Zulip::ResponseError, JSON.parse(response.body, symbolize_names: true)[:msg]
      end
    end

    def stream_event(event_types: [], narrow: [])
      queue_id, last_event_id = register(event_types: event_types, narrow: narrow)
      loop do
        response = get_events(queue_id: queue_id, last_event_id: last_event_id)
        if response[:result] == "success"
          response[:events].each do |event|
            last_event_id = event[:id]
            yield event
          end
        else
          raise Zulip::ResponseError, response["msg"]
        end
        sleep(1)
      end
    ensure
      unregister(queue_id)
    end

    def stream_message(narrow: [])
      stream_event(event_types: ["message"], narrow: narrow) do |event|
        yield event
      end
    end

    private

    def get_events(queue_id:, last_event_id:)
      response = @connection.get do |request|
        request.url("/api/v1/events")
        request.params["queue_id"] = queue_id
        request.params["last_event_id"] = last_event_id
      end
      if response.success?
        JSON.parse(response.body, symbolize_names: true)
      else
        raise Zulip::ResponseError, response.reason_phrase
      end
    end
  end
end
