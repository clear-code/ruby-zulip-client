# Zulip::Client

[Zulip](https://zulip.org/) client for [Ruby](https://www.ruby-lang.org/).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'zulip-client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install zulip-client

## Usage

Send message to stream:

```ruby
client = Zulip::Client.new(site: "https://zulip.example.com/",
                           username: "test-bot@zulip.example.com",
                           api_token: "xxxxxxxxxxxxx")
client.send_message(type: :stream, to: "general", subject: "projects", content: "Hello, Zulip!")
```

Send private message to users:

```ruby
client.send_message(type: :stream, to: "user@zulip.example.com", content: "Hello, Zulip!")
client.send_message(type: :stream, to: ["user1@zulip.example.com", "user2@zulip.example.com"], content: "Hello, Zulip!")
```

Receive all events:

```ruby
client.each_event do |event|
  p event
end
```

Receive message event:

```ruby
client.each_message do |event|
  p event
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/okkez/zulip-client.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

