lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "zulip/client/version"

Gem::Specification.new do |spec|
  spec.name          = "zulip-client"
  spec.version       = Zulip::Client::VERSION
  spec.authors       = ["okkez"]
  spec.email         = ["okkez000@gmail.com"]

  spec.summary       = "Zulip client for Ruby"
  spec.description   = "Zulip client for Ruby"
  spec.homepage      = "https://github.com/okkez/zulip-client-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) {|f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "faraday", ">= 0.11.0"
  spec.add_runtime_dependency "typhoeus", "~> 1.1.0"
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "test-unit", ">= 3.2.0"
  spec.add_development_dependency "webmock"
end
