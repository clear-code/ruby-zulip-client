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
        raise Zulip::ResponseError, reqponse.reason_phrase
      end
    end

    def stream_event(event_types: [], narrow: [])
      queue_id, last_event_id = register(event_types: event_types, narrow: narrow)
      response_reader, response_writer = IO.pipe
      command_reader, @command_writer = IO.pipe
      @running = true
      t = Thread.new do
        loop do
          break unless @running
          response = get_events(queue_id: queue_id, last_event_id: last_event_id)
          response_writer.write(response)
        end
      end
      buf = ""
      loop do
        reader, _writer, _exception = IO.select([response_reader, command_reader])
        case reader.first
        when response_reader
          buf << response_reader.readpartial(1024)
          begin
            res = JSON.parse(buf, symbolize_names: true)
          rescue JSON::ParserError => ex
            warn("#{ex.class}:#{ex.message}")
            next
          end
          buf = ""
          if res[:result] == "success"
            res[:events].each do |event|
              last_event_id = event[:id]
              if event_types.empty? || event_types.include?(event[:type])
                yield event
              end
            end
          else
            raise Zulip::ResponseError, res[:msg]
          end
        when command_reader
          break
        end
      end
      unregister(queue_id)
      t.join
    end

    def stream_message(narrow: [])
      stream_event(event_types: ["message"], narrow: narrow) do |event|
        yield event[:message]
      end
    end

    def close_stream
      @running = false
      @command_writer.write("q") if @command_writer
    end

    private

    def get_events(queue_id:, last_event_id:)
      response = @connection.get do |request|
        request.url("/api/v1/events")
        request.params["queue_id"] = queue_id
        request.params["last_event_id"] = last_event_id
      end
      if response.success?
        response.body
      else
        raise Zulip::ResponseError, response.reason_phrase
      end
    end
  end
end
