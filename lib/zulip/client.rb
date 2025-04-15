require "json"
require "uri"
require "faraday"
require "typhoeus"
require "typhoeus/adapters/faraday"

require "zulip/error"

Faraday.default_adapter = :typhoeus

module Zulip
  class Client
    DEFAULT_OPEN_TIMEOUT = 30
    DEFAULT_TIMEOUT = 90

    attr_accessor :debug

    def initialize(site:, username:, api_key:, **options)
      @site = URI.parse(site)
      @connection = Faraday.new(@site.to_s, options) do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.options[:open_timeout] ||= DEFAULT_OPEN_TIMEOUT
        faraday.options[:timeout] ||= DEFAULT_TIMEOUT
        yield faraday if block_given?
      end
      @connection.basic_auth(username, api_key)
      @running = false
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

    def send_public_message(to:, subject:, content:)
      send_message(type: :stream, to: to, subject: subject, content: content)
    end

    def send_private_message(to:, content:)
      send_message(type: :private, to: to, content: content)
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
        raise Zulip::ResponseError, response.reason_phrase
      end
    end

    def unregister(queue_id)
      response = @connection.delete do |request|
        request.url("/api/v1/events")
        request.body = { "queue_id" => queue_id }
      end
      case
      when response.success?
        JSON.parse(response.body, symbolize_names: true)[:result] == "success"
      when (400..499).include?(response.status)
        res = JSON.parse(response.body, symbolize_names: true)
        raise Zulip::ResponseError, res[:msg]
      else
        raise Zulip::ResponseError, response.reason_phrase
      end
    end

    def stream_event(event_types: [], narrow: [])
      @running = true
      queue_id, last_event_id = register(event_types: event_types, narrow: narrow)
      loop do
        break unless @running

        response = @connection.get do |request|
          request.url("/api/v1/events")
          request.params["queue_id"] = queue_id
          request.params["last_event_id"] = last_event_id
        end

        if response.success?
          res = JSON.parse(response.body, symbolize_names: true)
          raise Zulip::ResponseError, res[:msg] unless res[:result] == "success"
          res[:events].each do |event|
            last_event_id = event[:id]
            if event_types.empty? || event_types.include?(event[:type])
              yield event
            end
          end
        else
          case response.status
          when 400..499
            raise Zulip::ResponseError, response.reason_phrase
          when 500..599
            puts "Retrying..."
            sleep 1
          end
        end
      end
    ensure
      unregister(queue_id)
    end

    def stream_message(narrow: [])
      stream_event(event_types: ["message"], narrow: narrow) do |event|
        yield event[:message]
      end
    end

    def close_stream
      @running = false
    end
  end
end
