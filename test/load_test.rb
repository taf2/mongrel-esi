require 'net/http'
require 'open-uri'

# test the currency load
class LoadTest
  TEST_HOST='http://127.0.0.1:8000'
  TEST_PATH='/'
  EXPECTED_RESPONSE=File.read(File.join(File.dirname(__FILE__),'sample.html'))

  def initialize(trials)
    @trials = trials
    @trial = 0
    @reports = {}
  end

  def request_url
    TEST_HOST + TEST_PATH
  end

  # see: http://warrenseen.com/blog/2006/03/13/how-to-calculate-standard-deviation/
  def variance(population)
    n = 0
    mean = 0.0
    s = 0.0
    population.each { |x|
      n = n + 1
      delta = x - mean
      mean = mean + (delta / n)
      s = s + delta * (x - mean)
    }
    # if you want to calculate std deviation
    # of a sample change this to "s / (n-1)"
    return s / (n-1)
  end

  # calculate the standard deviation of a population
  # accepts: an array, the population
  # returns: the standard deviation
  def standard_deviation(population)
    Math.sqrt(variance(population).abs)
  end

  def report( type, image_path = "benchmark100.png", font_path="/usr/share/fonts/bitstream-vera/Vera.ttf" )
    require 'rubygems'
    require 'gruff'
    extras = {}
    g = Gruff::Line.new(2048)
    g.title = "MongrelESI Serial vs Parallel"
    g.font = font_path if font_path # my linux system's font 
    @reports[type].each do|key,values|
#      puts key.inspect
#      puts values.inspect
 #     total = 0
 #     values.each {|t| total += t }
 #     average = total / values.size
 #     std = standard_deviation(values)
      g.data(key,values)
 #     puts "#{key}: #{average} seconds (#{std})"
 #     extras[key] = {:std => std, :average => average}
    end
    labels = {}
    @trials.each_with_index do|t,index|
      #puts index.inspect, t.inspect
      labels[index] = t.to_s
    end
    g.labels = labels
    g.write(image_path)
  end

  def assert_equal( s1, s2 )
    if s1 != s2
      File.open("s1.html","w") do|f|
        f << s1
      end
      File.open("s2.html","w") do|f|
        f << s2
      end
      raise "Error response not matching expected library failure! 's1.html' Not equal to 's2.html'"
    end
  end

  def assert_not_nil( v )
    raise "Error: value should not be nil!" if v.nil?
  end

  def test_trial(trials,report_tag,url)
    require 'net/http'
    require 'open-uri'

    timer = Time.now
    threads = []

    trials.times do
      threads << Thread.new do
        t = Time.now
        assert_equal( EXPECTED_RESPONSE, open(url).read )
        (Time.now - t)
      end
    end

    times = []
    threads.each do|t|
      times << t.value
    end

    duration = Time.now - timer
    #average = (duration / trials)
    average = 0
    times.each { |t| average += t  }
    average /= times.size

    

    std = standard_deviation(times) if times.size > 1
 
    puts "Running net/http(#{report_tag}): #{trials} in #{average} seconds (#{std}), #{times.inspect}"
    @reports[:avg]["#{report_tag}"] ||= []
    @reports[:avg]["#{report_tag}"] << average
    if times.size > 1
      @reports[:std]["#{report_tag}"] ||= []
      @reports[:std]["#{report_tag}"] << std
    end
    @reports[:raw]["#{report_tag}-#{trials}"] ||= []
    @reports[:raw]["#{report_tag}-#{trials}"] += times
  end

  def run
    @reports = {:avg => {}, :std => {}, :raw => {}}
    @trials.each do|trial|
      test_trial(trial,:piped,'http://127.0.0.1:8000/')
      test_trial(trial,:serial,'http://127.0.0.1:8001/')
    end
  end
end

test = LoadTest.new([1,2,5,10]) #,80,100,200,300,400])
test.run
test.report(:avg, 'benchmark-averages-50.png')
test.report(:std, 'benchmark-std-50.png')
test.report(:raw, 'benchmark-times-50.png')
