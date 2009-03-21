# line 1 "ruby_esi.rl"
module ESI
  class ParserMachine

# line 100 "ruby_esi.rl"


    def initialize
      
# line 11 "machine.rb"
class << self
	attr_accessor :_esi_actions
	private :_esi_actions, :_esi_actions=
end
self._esi_actions = [
	0, 1, 9, 2, 9, 0, 2, 9, 
	1, 2, 9, 2, 2, 9, 3, 2, 
	9, 4, 2, 9, 5, 2, 9, 6, 
	2, 9, 7, 2, 9, 8, 3, 9, 
	0, 1, 3, 9, 3, 1, 4, 9, 
	0, 3, 1, 4, 9, 3, 6, 1
]

class << self
	attr_accessor :_esi_key_offsets
	private :_esi_key_offsets, :_esi_key_offsets=
end
self._esi_key_offsets = [
	0, 1, 4, 6, 8, 10, 12, 15, 
	19, 21, 23, 25, 28, 36, 48, 59, 
	69, 75, 85, 94, 106, 117, 119, 130, 
	140, 150, 160, 170, 180, 191, 201, 211, 
	221, 231, 246, 256, 265, 277, 288, 298, 
	304, 314, 325, 335, 345, 355, 365, 375, 
	386, 396, 406, 416, 426, 441, 451, 453, 
	455, 456, 457, 466, 475
]

class << self
	attr_accessor :_esi_trans_keys
	private :_esi_trans_keys, :_esi_trans_keys=
end
self._esi_trans_keys = [
	60, 47, 60, 101, 60, 101, 60, 115, 
	60, 105, 58, 60, 60, 97, 122, 60, 
	62, 97, 122, 60, 115, 60, 105, 58, 
	60, 60, 97, 122, 32, 47, 60, 62, 
	9, 13, 97, 122, 32, 45, 47, 60, 
	62, 95, 9, 13, 65, 90, 97, 122, 
	32, 45, 47, 60, 95, 9, 13, 65, 
	90, 97, 122, 45, 60, 61, 95, 48, 
	57, 65, 90, 97, 122, 32, 34, 39, 
	60, 9, 13, 33, 60, 95, 125, 35, 
	38, 40, 90, 97, 123, 34, 39, 60, 
	95, 125, 33, 90, 97, 123, 32, 45, 
	47, 60, 62, 95, 9, 13, 65, 90, 
	97, 122, 32, 45, 47, 60, 95, 9, 
	13, 65, 90, 97, 122, 60, 62, 34, 
	39, 47, 60, 95, 101, 125, 33, 90, 
	97, 123, 34, 39, 60, 95, 101, 125, 
	33, 90, 97, 123, 34, 39, 60, 95, 
	115, 125, 33, 90, 97, 123, 34, 39, 
	60, 95, 105, 125, 33, 90, 97, 123, 
	34, 39, 58, 60, 95, 125, 33, 90, 
	97, 123, 34, 39, 60, 95, 123, 125, 
	33, 90, 97, 122, 34, 39, 60, 62, 
	95, 123, 125, 33, 90, 97, 122, 34, 
	39, 60, 95, 115, 125, 33, 90, 97, 
	123, 34, 39, 60, 95, 105, 125, 33, 
	90, 97, 123, 34, 39, 58, 60, 95, 
	125, 33, 90, 97, 123, 34, 39, 60, 
	95, 123, 125, 33, 90, 97, 122, 32, 
	34, 39, 47, 60, 62, 95, 123, 125, 
	9, 13, 33, 90, 97, 122, 34, 39, 
	60, 62, 95, 125, 33, 90, 97, 123, 
	34, 39, 60, 95, 125, 33, 90, 97, 
	123, 32, 45, 47, 60, 62, 95, 9, 
	13, 65, 90, 97, 122, 32, 45, 47, 
	60, 95, 9, 13, 65, 90, 97, 122, 
	45, 60, 61, 95, 48, 57, 65, 90, 
	97, 122, 32, 34, 39, 60, 9, 13, 
	33, 60, 95, 125, 35, 38, 40, 90, 
	97, 123, 34, 39, 47, 60, 95, 101, 
	125, 33, 90, 97, 123, 34, 39, 60, 
	95, 101, 125, 33, 90, 97, 123, 34, 
	39, 60, 95, 115, 125, 33, 90, 97, 
	123, 34, 39, 60, 95, 105, 125, 33, 
	90, 97, 123, 34, 39, 58, 60, 95, 
	125, 33, 90, 97, 123, 34, 39, 60, 
	95, 123, 125, 33, 90, 97, 122, 34, 
	39, 60, 62, 95, 123, 125, 33, 90, 
	97, 122, 34, 39, 60, 95, 115, 125, 
	33, 90, 97, 123, 34, 39, 60, 95, 
	105, 125, 33, 90, 97, 123, 34, 39, 
	58, 60, 95, 125, 33, 90, 97, 123, 
	34, 39, 60, 95, 123, 125, 33, 90, 
	97, 122, 32, 34, 39, 47, 60, 62, 
	95, 123, 125, 9, 13, 33, 90, 97, 
	122, 34, 39, 60, 62, 95, 125, 33, 
	90, 97, 123, 60, 62, 60, 62, 60, 
	60, 34, 39, 60, 95, 125, 33, 90, 
	97, 123, 34, 39, 60, 95, 125, 33, 
	90, 97, 123, 60, 0
]

class << self
	attr_accessor :_esi_single_lengths
	private :_esi_single_lengths, :_esi_single_lengths=
end
self._esi_single_lengths = [
	1, 3, 2, 2, 2, 2, 1, 2, 
	2, 2, 2, 1, 4, 6, 5, 4, 
	4, 4, 5, 6, 5, 2, 7, 6, 
	6, 6, 6, 6, 7, 6, 6, 6, 
	6, 9, 6, 5, 6, 5, 4, 4, 
	4, 7, 6, 6, 6, 6, 6, 7, 
	6, 6, 6, 6, 9, 6, 2, 2, 
	1, 1, 5, 5, 1
]

class << self
	attr_accessor :_esi_range_lengths
	private :_esi_range_lengths, :_esi_range_lengths=
end
self._esi_range_lengths = [
	0, 0, 0, 0, 0, 0, 1, 1, 
	0, 0, 0, 1, 2, 3, 3, 3, 
	1, 3, 2, 3, 3, 0, 2, 2, 
	2, 2, 2, 2, 2, 2, 2, 2, 
	2, 3, 2, 2, 3, 3, 3, 1, 
	3, 2, 2, 2, 2, 2, 2, 2, 
	2, 2, 2, 2, 3, 2, 0, 0, 
	0, 0, 2, 2, 0
]

class << self
	attr_accessor :_esi_index_offsets
	private :_esi_index_offsets, :_esi_index_offsets=
end
self._esi_index_offsets = [
	0, 2, 6, 9, 12, 15, 18, 21, 
	25, 28, 31, 34, 37, 44, 54, 63, 
	71, 77, 85, 93, 103, 112, 115, 125, 
	134, 143, 152, 161, 170, 180, 189, 198, 
	207, 216, 229, 238, 246, 256, 265, 273, 
	279, 287, 297, 306, 315, 324, 333, 342, 
	352, 361, 370, 379, 388, 401, 410, 413, 
	416, 418, 420, 428, 436
]

class << self
	attr_accessor :_esi_indicies
	private :_esi_indicies, :_esi_indicies=
end
self._esi_indicies = [
	1, 0, 2, 1, 3, 0, 1, 4, 
	0, 1, 5, 0, 1, 6, 0, 7, 
	1, 0, 1, 8, 0, 1, 9, 8, 
	0, 1, 10, 0, 1, 11, 0, 12, 
	1, 0, 1, 13, 0, 14, 15, 1, 
	16, 14, 13, 0, 17, 18, 19, 1, 
	20, 18, 17, 18, 18, 0, 17, 18, 
	19, 1, 18, 17, 18, 18, 0, 18, 
	1, 21, 18, 18, 18, 18, 0, 22, 
	23, 23, 1, 22, 0, 24, 25, 24, 
	24, 24, 24, 24, 0, 26, 26, 25, 
	24, 24, 24, 24, 0, 27, 18, 28, 
	1, 20, 18, 27, 18, 18, 0, 27, 
	18, 28, 1, 18, 27, 18, 18, 0, 
	1, 29, 0, 26, 26, 30, 25, 24, 
	31, 24, 24, 24, 0, 26, 26, 25, 
	24, 32, 24, 24, 24, 0, 26, 26, 
	25, 24, 33, 24, 24, 24, 0, 26, 
	26, 25, 24, 34, 24, 24, 24, 0, 
	26, 26, 35, 25, 24, 24, 24, 24, 
	0, 26, 26, 25, 24, 24, 24, 24, 
	36, 0, 26, 26, 25, 37, 24, 24, 
	24, 24, 36, 0, 26, 26, 25, 24, 
	38, 24, 24, 24, 0, 26, 26, 25, 
	24, 39, 24, 24, 24, 0, 26, 26, 
	40, 25, 24, 24, 24, 24, 0, 26, 
	26, 25, 24, 24, 24, 24, 41, 0, 
	14, 26, 26, 42, 25, 43, 24, 24, 
	24, 14, 24, 41, 0, 26, 26, 25, 
	44, 24, 24, 24, 24, 0, 46, 46, 
	47, 45, 45, 45, 45, 0, 48, 49, 
	28, 1, 20, 49, 48, 49, 49, 0, 
	48, 49, 28, 1, 49, 48, 49, 49, 
	0, 49, 1, 50, 49, 49, 49, 49, 
	0, 51, 52, 52, 1, 51, 0, 45, 
	47, 45, 45, 45, 45, 45, 0, 46, 
	46, 53, 47, 45, 54, 45, 45, 45, 
	0, 46, 46, 47, 45, 55, 45, 45, 
	45, 0, 46, 46, 47, 45, 56, 45, 
	45, 45, 0, 46, 46, 47, 45, 57, 
	45, 45, 45, 0, 46, 46, 58, 47, 
	45, 45, 45, 45, 0, 46, 46, 47, 
	45, 45, 45, 45, 59, 0, 46, 46, 
	47, 60, 45, 45, 45, 45, 59, 0, 
	46, 46, 47, 45, 61, 45, 45, 45, 
	0, 46, 46, 47, 45, 62, 45, 45, 
	45, 0, 46, 46, 63, 47, 45, 45, 
	45, 45, 0, 46, 46, 47, 45, 45, 
	45, 45, 64, 0, 14, 46, 46, 65, 
	47, 66, 45, 45, 45, 14, 45, 64, 
	0, 46, 46, 47, 67, 45, 45, 45, 
	45, 0, 1, 68, 0, 1, 69, 0, 
	1, 0, 71, 70, 74, 74, 75, 73, 
	73, 73, 73, 72, 74, 74, 75, 73, 
	73, 73, 73, 72, 76, 72, 0
]

class << self
	attr_accessor :_esi_trans_targs_wi
	private :_esi_trans_targs_wi, :_esi_trans_targs_wi=
end
self._esi_trans_targs_wi = [
	0, 1, 2, 8, 3, 4, 5, 6, 
	7, 0, 9, 10, 11, 12, 13, 55, 
	0, 14, 15, 54, 57, 16, 16, 17, 
	18, 22, 19, 20, 21, 57, 23, 29, 
	24, 25, 26, 27, 28, 18, 30, 31, 
	32, 33, 34, 18, 58, 35, 36, 41, 
	37, 38, 39, 39, 40, 42, 48, 43, 
	44, 45, 46, 47, 35, 49, 50, 51, 
	52, 53, 35, 59, 60, 60, 0, 1, 
	0, 35, 36, 41, 1
]

class << self
	attr_accessor :_esi_trans_actions_wi
	private :_esi_trans_actions_wi, :_esi_trans_actions_wi=
end
self._esi_trans_actions_wi = [
	1, 3, 1, 1, 1, 1, 1, 1, 
	1, 27, 1, 1, 1, 1, 9, 9, 
	24, 1, 1, 9, 15, 18, 1, 1, 
	1, 3, 21, 1, 1, 12, 1, 1, 
	1, 1, 1, 1, 1, 27, 1, 1, 
	1, 1, 9, 24, 1, 1, 21, 3, 
	1, 1, 18, 1, 1, 1, 1, 1, 
	1, 1, 1, 1, 27, 1, 1, 1, 
	1, 9, 24, 1, 12, 1, 6, 30, 
	34, 34, 43, 38, 38
]

class << self
	attr_accessor :esi_start
end
self.esi_start = 56;
class << self
	attr_accessor :esi_first_final
end
self.esi_first_final = 56;
class << self
	attr_accessor :esi_error
end
self.esi_error = -1;

class << self
	attr_accessor :esi_en_main
end
self.esi_en_main = 56;

# line 104 "ruby_esi.rl"
    end

    # process a block of esi tags
    def process(data)
      if @data
  #      puts "append : #{@mark} : #{p}"
        data = @data + data
        p = @data.length
      end
      @mark ||= 0
      p ||= 0
      pe ||= data.length
      @cs ||= esi_start
      cs = @cs
  #    puts "process: #{cs.inspect} :start #{data.inspect}, #{p}"
      
# line 283 "machine.rb"
begin
	_klen, _trans, _keys, _acts, _nacts = nil
	if p != pe
	while true
	_break_resume = false
	begin
	_break_again = false
	_keys = _esi_key_offsets[cs]
	_trans = _esi_index_offsets[cs]
	_klen = _esi_single_lengths[cs]
	_break_match = false
	
	begin
	  if _klen > 0
	     _lower = _keys
	     _upper = _keys + _klen - 1

	     loop do
	        break if _upper < _lower
	        _mid = _lower + ( (_upper - _lower) >> 1 )

	        if data[p] < _esi_trans_keys[_mid]
	           _upper = _mid - 1
	        elsif data[p] > _esi_trans_keys[_mid]
	           _lower = _mid + 1
	        else
	           _trans += (_mid - _keys)
	           _break_match = true
	           break
	        end
	     end # loop
	     break if _break_match
	     _keys += _klen
	     _trans += _klen
	  end
	  _klen = _esi_range_lengths[cs]
	  if _klen > 0
	     _lower = _keys
	     _upper = _keys + (_klen << 1) - 2
	     loop do
	        break if _upper < _lower
	        _mid = _lower + (((_upper-_lower) >> 1) & ~1)
	        if data[p] < _esi_trans_keys[_mid]
	          _upper = _mid - 2
	        elsif data[p] > _esi_trans_keys[_mid+1]
	          _lower = _mid + 2
	        else
	          _trans += ((_mid - _keys) >> 1)
	          _break_match = true
	          break
	        end
	     end # loop
	     break if _break_match
	     _trans += _klen
	  end
	end while false
	_trans = _esi_indicies[_trans]
	cs = _esi_trans_targs_wi[_trans]
	break if _esi_trans_actions_wi[_trans] == 0
	_acts = _esi_trans_actions_wi[_trans]
	_nacts = _esi_actions[_acts]
	_acts += 1
	while _nacts > 0
		_nacts -= 1
		_acts += 1
		case _esi_actions[_acts - 1]
when 0:
# line 7 "ruby_esi.rl"
		begin

    @mark = p
  		end
# line 7 "ruby_esi.rl"
when 1:
# line 10 "ruby_esi.rl"
		begin

  		end
# line 10 "ruby_esi.rl"
when 2:
# line 14 "ruby_esi.rl"
		begin

    @tag_text = data[@mark,p-@mark]
    @tag_info = {} # store the tag attributes
    @tag_info[:name] = @tag_text.sub('<','').strip
    @tag_info[:attributes] = {}
#    puts "have esi tag at #{p}=>#{@mark}:#{data[p,1].inspect} with data #{@tag_text.inspect}"
    @mark = p
  		end
# line 14 "ruby_esi.rl"
when 3:
# line 23 "ruby_esi.rl"
		begin

#    puts "parsed esi tag at #{p}=>#{@mark}:#{data[p,1].inspect} with data #{@tag_text.inspect}"
    @start_tag.call @tag_info[:name], @tag_info[:attributes] if @start_tag
    @end_tag.call @tag_info[:name] if @end_tag
    @attr_key = nil
    @attr_value = nil
    @tag_text = nil
    @tag_info = nil
  		end
# line 23 "ruby_esi.rl"
when 4:
# line 33 "ruby_esi.rl"
		begin

#    puts "parsed esi tag at #{p}=>#{@mark}:#{data[p,1].inspect} with data #{@tag_text.inspect}"
    @start_tag.call @tag_info[:name], @tag_info[:attributes] if @start_tag
    @attr_key = nil
    @attr_value = nil
    @tag_text = nil
    @tag_info = nil
  		end
# line 33 "ruby_esi.rl"
when 5:
# line 42 "ruby_esi.rl"
		begin

    @attr_key = data[@mark,p-@mark]
    @mark += (@attr_key.size)
    @attr_key.gsub!(/^['"]/,'')
    @attr_key.strip!
#    puts "SeeAttributeKey: #{data[@mark,1].inspect}: #{data[p,1].inspect} #{@attr_key.inspect}"
  		end
# line 42 "ruby_esi.rl"
when 6:
# line 50 "ruby_esi.rl"
		begin

    @attr_value = data[@mark,p-@mark]
    @attr_value.strip!
    @attr_value.gsub!(/^=?\s*['"]/,'')
    @attr_value.gsub!(/['"]$/,'')

    @tag_info[:attributes][@attr_key] = @attr_value
#    puts "SeeAttributeValue: #{p} #{data[@mark,1].inspect}: #{data[p,1].inspect} #{@attr_key.inspect} => #{@attr_value.inspect}"
    @mark = p
  		end
# line 50 "ruby_esi.rl"
when 7:
# line 61 "ruby_esi.rl"
		begin

    tag_text = data[@mark+1,p-@mark-1]
    @start_tag.call tag_text, {} if @start_tag
#    puts "Block start: #{p} #{tag_text}"
  		end
# line 61 "ruby_esi.rl"
when 8:
# line 67 "ruby_esi.rl"
		begin

    tag_text = data[@mark+2,p-@mark-2]
    @end_tag.call tag_text if @end_tag
#    puts "Block end: #{p} #{tag_text}"
  		end
# line 67 "ruby_esi.rl"
when 9:
# line 73 "ruby_esi.rl"
		begin

#    print " [#{data[p,1].inspect}:#{cs}] " if $debug

    case cs
    when 0
      # NOTE: state 12 is the character state before <esi:try>, state 7 is the character before </esi:try>
      #                                                     |                                           |
      #                                                     - state 12                                  - state 7
      # state 60 is for empty inline tags e.g.
      # <esi:include/>
      #              |
      #              - 60

      if @prev_state != 12 and @prev_state != 7
        if !@prev_buffer.empty? and (@prev_state != (esi_en_main + 1)) and @prev_state != 60
          stream_buffer @prev_buffer
        end
        stream_buffer data[p,1]
      end
      @prev_buffer = ""
    else
      @prev_buffer << data[p,1]
    end
    @prev_state = cs
  		end
# line 73 "ruby_esi.rl"
# line 472 "machine.rb"
		end # action switch
	end
	end while false
	break if _break_resume
	p += 1
	break if p == pe
	end
	end
	end
# line 120 "ruby_esi.rl"
      @cs = cs
      if( @cs != esi_start && @cs != 0 )
  #    puts "append process: #{@cs.inspect}"
        @data = data
      else
        @data = nil
      end
    end

    def finish
      
# line 494 "machine.rb"
# line 131 "ruby_esi.rl"
    end

  end

end
