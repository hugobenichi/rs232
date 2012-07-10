require 'rs232'

t = RS232.new 'COM1'

t.write '?:V'
puts t.read

t.write 'Q:'
puts t.read

t.write 'H:1-'

#$stdin.gets

#t.write 'M:1+P10000'
#t.write 'G:'

puts "end of program"
t.stop