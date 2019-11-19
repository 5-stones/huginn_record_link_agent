# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "huginn_record_link_agent"
  spec.version       = "1.0.0"
  spec.authors       = ["Mike Rogers"]
  spec.email         = ["mrogers@weare5stones.com"]

  spec.summary       = %q{Write a short summary, because Rubygems requires one.}
  #spec.description   = %q{Write a longer description or delete this line.}

  spec.homepage      = "https://github.com/5stones/huginn_http_request_agent"

  spec.license       = "MIT"


  spec.files         = Dir['LICENSE.txt', 'lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = Dir['spec/**/*.rb'].reject { |f| f[%r{^spec/huginn}] }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "huginn_agent"
end
