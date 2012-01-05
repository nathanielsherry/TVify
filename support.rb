#!/usr/bin/ruby1.9.1

#	 Copyright 2010 by Nathaniel Sherry
#
#    This file is part of TVify.
#
#    TVify is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    TVify is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with TVify.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'

class TitleCase
 
  def initialize(string)
    @raw_string = string
    convert
  end
 
  def to_s
    @titlecase_string
  end
  
  def original
    @raw_string
  end
  
  def self.small_words
    @small_words = %w(a an and as at but by en for if in of on or the to v[.] via vs[.]?)
  end
 
  def self.small_words=(words)
    @small_words = words
  end
  
  def self.small_words_re
    small_words.join('|')
  end
  
  private
  
    def convert
      @titlecase_string = ""
      @raw_string.each_line do |line|
        line.split(/( [:.;?!][ ] | (?:[ ]|^)[""] )/ux).each do |sub_phrase|
          
          # upper case phrase words
          sub_phrase = uppercase_phrase(sub_phrase)
 
          # lower case small words
          sub_phrase.gsub!(/\b(#{TitleCase.small_words_re})\b/ui){|small| small.downcase }
 
          # upper case small words at start of phrase
          sub_phrase.gsub!(/\A[[:punct:]]*(#{TitleCase.small_words_re})\b/u){|small| small.capitalize }
 
          # upper case small words at end of phrase
          sub_phrase.gsub!(/\b(#{TitleCase.small_words_re})[[:punct:]]*\Z/u){|small| small.capitalize }
 
          sub_phrase = special_cases(sub_phrase)
          @titlecase_string << sub_phrase
        end
      end
    end
    
    def uppercase_phrase(phrase)
      phrase.gsub!(/\b([[:alpha:]][[:lower:].'']*)\b/u) do |word|
        if /[[:alpha:]][.][[:alpha:]]/u.match(word)
          word
        else
          word.downcase.capitalize
        end
      end
      phrase
    end
    
    def special_cases(phrase)
      phrase.gsub!(/\b(v[s\.])\b/ui){ |vs| vs.downcase }
      phrase.gsub!(/(['']S)\b/u) { |aps| aps.downcase }
      phrase.gsub!(/\b(Q&A)\b/ui){|special| special.upcase }
      phrase
    end
  
end
 
class String
 
  def titlecase
    TitleCase.new(self).to_s
  end
 
  def TheToEnd
  
	return self if self.size == 0

	words = self.split(" ")
	if words[0].downcase.strip == "the"
		the = words.shift
		words[-1] += ","
		words << the
		return words.join(" ")
	end
	return self
  
  end
 
end


class Params

	attr_accessor :debug, :simulate, :no_move, :no_title, :lookup_replace_showname, :prepend_showname, :append_showname, :replace_showname, :source, :target, :hashonly, :targetfile

	def initialize
	
		@debug=false
		@simulate=false
		@no_move=false
		@no_title=false
		@lookup_replace_showname=false
		@prepend_showname=nil
		@append_showname=nil
		@replace_showname=nil
		@source="./"
		@target="./"
		@hashonly=false
		@targetfile=nil
	
	end

end
