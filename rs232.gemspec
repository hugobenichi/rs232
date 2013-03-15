Gem::Specification.new do |spec|

  spec.name        = 'rs232'
  spec.version     = '0.1.3'
  spec.date        = '2012-07-24'
  spec.summary     = "Ruby interface to Windows Serial Port API"
  spec.description = "Allows to script access to the serial port on Windows. Simple read and write commands"
  spec.authors     = ["Hugo Benichi"]
  spec.email       = 'hugo[dot]benichi[at]m4x[dot]org'
  spec.homepage    = "http://github.com/hugobenichi/rs232"
  
  spec.files       = ['lib/rs232.rb', 'test/test_rs232.rb'] 
  spec.files      << 'rakefile.rb'
  spec.files      << 'README'
  
  spec.add_dependency 'ffi'
  
end
