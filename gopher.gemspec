require_relative 'lib/gopher'

Gem::Specification.new do |s|
  s.name          = 'gopher'
  s.version       = Gopher::VERSION
  s.licenses      = ['ISC']
  s.summary       = "gopher server and dsl"
  s.description   = ""
  s.authors       = ["umeldt"]
  s.email         = 'chris@svindseth.jp'
  s.files         = Dir.glob("{bin,lib}/**/*")+ %w(LICENSE README)
  s.executables   = ['gopher']
  s.require_paths = ["lib", "bin"]
  s.homepage      = 'https://svindseth.jp/gopher'

  s.add_runtime_dependency "word_wrap", "1.0.0"
  s.add_runtime_dependency "eventmachine", "~> 1.2", ">=1.2.0"
  s.add_development_dependency "rake", "10.4.2"
end

