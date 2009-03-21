require 'rubygems'
require 'gruff'

trunkcsv = File.read(File.join(File.dirname(__FILE__),'benchmarks','csv-perf-trunk')).split("\n")
serial04csv = File.read(File.join(File.dirname(__FILE__),'benchmarks','csv-perf-serial0.4')).split("\n")

trunkcsv.shift
serial04csv.shift

g = Gruff::Line.new(1024)
g.title = "trunk vs 0.4"
g.font = "/usr/share/fonts/bitstream-vera/Vera.ttf" # my linux system's font 


g.data("trunk",trunkcsv.collect {|pair| pair.split(",").last.to_f })

g.data("serial 0.4",serial04csv.collect {|pair| pair.split(",").last.to_f })

number_requests = 2000

# need to compute the percentiles
labels = { 1 => '1', 20 => '20', 40 => '40', 60 => '60', 80 => '80', 99 => '99' }

#g.hide_dots = true
g.labels = labels
g.y_axis_label = "Time per request (ms)"
g.x_axis_label = "Requests"
g.theme_37signals

puts "write: #{g.inspect}"
g.write(File.join(File.dirname(__FILE__),'benchmarks','perf.png'))
