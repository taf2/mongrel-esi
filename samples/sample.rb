# use this to start and stop the sample
case ARGV[0]
  when 'start'
    4.times do |i|
      frag = "frag#{i+1}"
      port = "400#{i+1}"
      system("cd #{frag} && merb -I #{frag}.rb -p #{port} -e production -d -a ebb")
    end
    system("cd simple && merb -I simple.rb -p 4000 -e production -d -a ebb")
  when 'restart'
    4.times do |i|
      frag = "frag#{i+1}"
      port = "400#{i+1}"
      system("cd #{frag} && merb -K #{port}")
      system("cd #{frag} && merb -I #{frag}.rb -p #{port} -e production -d -a ebb")
    end
    system("cd simple && merb -K 4000")
    system("cd simple && merb -I simple.rb -p 4000 -e production -d -a ebb")
  when 'stop'
    4.times do |i|
      frag = "frag#{i+1}"
      port = "400#{i+1}"
      system("cd #{frag} && merb -K #{port}")
    end
    system("cd simple && merb -K 4000")
  else
    puts "usage: ruby #{__FILE__} (start|stop|restart)"
end
