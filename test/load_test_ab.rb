#!/usr/bin/env ruby
# use ab to get benchmark performance readings

# measuring concurrency from 1 to 20
# doing 1000 request per iteration
n = 1000

5.times do|c|
  c += 1
#  system("ab -n #{n} -c #{c} -e '#{File.join(File.dirname(__FILE__),'benchmarks',"perf-serial0.4-n#{n}-c#{c}.csv")}' http://127.0.0.1:8001/")
  system("ab -n #{n} -c #{c} -e '#{File.join(File.dirname(__FILE__),'benchmarks',"perf-trunk-n#{n}-c#{c}.csv")}' http://127.0.0.1:8000/")
end
#system("ab -n #{n} -c #{c} -e '#{File.join(File.dirname(__FILE__),'benchmarks','csv-perf-trunk')}' http://127.0.0.1:4444/")
