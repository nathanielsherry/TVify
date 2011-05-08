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

	attr_accessor :debug, :simulate, :no_move, :no_title, :prepend_showname, :append_showname, :replace_showname, :source, :target, :hashonly, :targetfile

	def initialize
	
		@debug=false
		@simulate=false
		@no_move=false
		@no_title=false
		@prepend_showname=nil
		@append_showname=nil
		@replace_showname=nil
		@source="./"
		@target="./"
		@hashonly=false
		@targetfile=nil
	
	end

end

def matchEpisodeNumber(part, index, debug)

	ep = []

	part.strip!

	puts "Episode Number?: " + part if debug

	#***multi-part episode matching comes first.***
	#eg S01E01E02
	match = part =~ /[Ss][0-9].?[Ee][0-9].?[Ee][0-9].?/
	if match == 0
		season = part[part.index(/[Ss]/) + 1, part.index(/[Ee]/)-1]
		e_ind1 = part.index(/[Ee]/)
		e_ind2 = part.index(/[Ee]/, e_ind1+1)
		ep << part[e_ind1 + 1..e_ind2-1]
		ep << part[e_ind2 + 1..-1]
		#endind = index
		return index, season, ep
	end

	#eg S01E0102
	match = part =~ /[Ss][0-9].?[Ee][0-9][0-9][0-9][0-9]/
	if match == 0
		season = part[part.index(/[Ss]/) + 1, part.index(/[Ee]/)-1]
		e_ind = part.index(/[Ee]/)
		ep << part[part.index(/[Ee]/) + 1, 2]
		ep << part[part.index(/[Ee]/) + 3, 2]
		#endind = index
		return index, season, ep
	end
	
	#INTERNAL FORMAT
	#eg 1x01-02
	#alternate matches 01x01x02
	match = part =~ /[0-9][0-9]?[xX][0-9][0-9]?[-x][0-9][0-9]?/
	if match == 0
		sep = part.downcase.split("x", 2)
		
		season = sep[0]
		ep << sep[1].split(/[-x]/)
		endind = index
		return index, season, ep
	end

	#eg 1x0102
	match = part =~ /[0-9][0-9]?[xX][0-9][0-9][0-9][0-9]?/
	if match == 0
		sep = part.downcase.split "x"
		
		season = sep[0]
		ep << sep[1][0,2]
		ep << sep[1][2,2]
		endind = index
		return index, season, ep
	end

	#***single episode matchings***
	#eg S01E01
	match = part =~ /[Ss][0-9].?[Ee][0-9].?/
	if match == 0
		season = part[part.index(/[Ss]/) + 1, part.index(/[Ee]/)-1]
		ep << part[part.index(/[Ee]/) + 1..-1]
		endind = index
		return index, season, ep
	end
	
	#INTERNAL FORMAT
	#eg 1x01
	match = part =~ /[0-9][0-9]?[xX][0-9].?/
	if match == 0
		sep = part.downcase.split "x"
		
		season = sep[0]
		ep << sep[1]
		endind = index
		return index, season, ep
	end

	

	#clashes with year (eg Doctor Who 2005)
	#so we refuse to match [1-9]### numbers
	#this may interfere with shows that run for
	#10+ seasons, but its better than not matching it
	#at all
	#eg 0101
	match = part =~ /0[0-9][0-9][0-9]/
	if match == 0 and part.strip.length == 4
		#season = part[0,1] if part.length == 3
		season = part[0..1]
		ep << part[-2..-1]
		endind = index
		return index, season, ep
	end


#=begin
	#eg 101
	match = part =~ /[0-9][0-9][0-9]/
	if match == 0 and part.strip.length == 3
		season = part[0,1] if part.length == 3
		#season = part[0..1] if part.length == 4
		ep << part[-2..-1]
		endind = index
		return index, season, ep
	end
	
#=end	
	
	#eg [1x01]
	#todo: cant this merge with the one avobe using '\[?' ?
	#parsing would get more complicated, but...
	match = part =~ /\[[0-9][0-9]?[xX][0-9][0-9]\]?/
	if match == 0
		sep = part[1..-2].downcase.split "x"
		season = sep[0]
		ep << sep[1]
		endind = index
		return index, season, ep
	end
	
	
	#eg 1.01
	match = part =~ /[0-9]\.[0-9][0-9]/
	if match == 0 and part.strip.length == 4
		#season = part[0,1] if part.length == 3
		season = part[0..1]
		ep << part[-2..-1]
		endind = index
		return index, season, ep
	end
	
	
	return nil, 0, []

end

#takes a list of title parts, a start index, and a list of credit strings
#looks through list until it finds
def removeCredits(parts, ind, credits, debug)

	title = ""

	while true
		
		return title if ind >= parts.size
		
		newpart = parts[ind].chomp.strip
		ended = false
		ended = credits.map{|credit| newpart[0..credit.size-1] == credit}.inject(false){|a,b| a or b}
		
		#credits.each{|credit| ended = true if newpart[0..credit.size-1] == credit}
		puts "Found Title Fragment: #{newpart}" if (not ended) and debug
		puts "Title Ended Search on: #{newpart}" if ended and debug
		return title if ended

		title += " " if title != ""
		title += parts[ind].strip
		ind += 1
	end

	return title

end



def splitTitleToParts(name, epNameParse=false)

	if (epNameParse)
		parts = name.split(/[ ._-]/)
		parts = parts.select{|part| part.strip != "-"}
	else
		parts = name.split(/[ ._]/)
	end
	
	return parts

end



def makeNewNames(source, target, no_move, showname, showPath, title, season, ep, file_ext)
	#source: source path
	#target: target path - root of TV library
	#no_move: don't move to new folder
	#showname: single string name of show
	#showpath: showname split by ':', formatted (eg "Practice, The")
	#title: episode title
	#season: season number string
	#ep: episodes string array
	#file_ext: file extension string
	
	puts "====="
	puts showname
	
	if showname != nil and showPath != nil and title != nil and ep != nil and season != nil
	
		
	
		path = showPath.join("/")
		path += "/" + loadSegments[showname] if hasSegment?(showname)
	
		newdir = target + "/#{path}/Season #{season.to_i}/"
		newdir = source if no_move
	
		newname = "#{newdir}#{showname} - #{season.to_i}x" +  ep.join("-")
		newname += " - #{title}" if title != ""
		
	elsif showname != nil
	
		newdir = target + "/"
		newdir = source if no_move
	
		newname = "#{newdir}#{showname}"
		
	end
	
	newname += "." + file_ext
	
	return newdir, newname

end


def findFilesWithExtensions(dir, exts=loadFileExtensions)
	exts.map{|ext| `ls "#{dir}" | grep -i .#{ext}$`.split("\n")}.inject(:+)
end


def defaultTarget()
	
	filename = File.dirname(__FILE__)+"/tv-folder"
	default_path = File.expand_path("~/Videos/TV/")
	
	#if the file does not exist, create a new file with this information
	if not File.exists?(filename)
		`echo "#{default_path}" >> #{filename}`
	end
	
	path = `cat #{filename}`.strip
	FileUtils.mkdir_p(path)
	return path
	
end


def parseFilenameMovie(name, creditStrings, params)

	puts "\n\n\nExamining as Movie:" + name if params.debug
	
	file_ext = splitTitleToParts(name, true).last.strip
	
	parts = splitTitleToParts(name)
	title = removeCredits(parts, 0, creditStrings, params.debug)
	
	p title
	
	newdir, newname = makeNewNames(params.source, params.target, params.no_move, title, nil, nil, nil, nil, file_ext)
	
	return newdir, newname
	
	
end


def parseFilename(name, creditStrings, params)

		puts "\n\n\nExamining " + name if params.debug

		season = 0
		ep = []
		endind = -1
		#title_swap = false

		#split up the file name into parts
		parts = splitTitleToParts(name)
		puts "PARTS:\n" + parts.map{|p| "\t"+p+"\n"}.join("") if params.debug
		
		file_ext = splitTitleToParts(name, true).last.strip
		
		#find the part that matches the episode number. Everything before this is the show title.
		#everything after it is Episode Title, Credits, File Ext
		parts.each_with_index{|part, index|

			endind, season, ep = matchEpisodeNumber(part, index, params.debug)
			if endind != nil
				titleparts = splitTitleToParts(parts[endind+1..-1].join(" "), true)
				parts = parts[0..endind] + titleparts
				break 
			end

		}
		
		#pad episode numbers (not season numbers) with 0s
		ep = ep.map{|e| e.size == 1 ? "0" + e  : e}
		
		#if there was a title, join all the parts with spaces
		#if there was no title, we assume that the title has been placed after the episode number by some poor misguided fool.
		if endind != nil and endind != 0 and parts.size > 0
			shownameparts = parts[0..endind-1]
			
			while shownameparts[-1].strip == "-"
				shownameparts = shownameparts[0..-2]
			end
			showname = "#{shownameparts.join(" ")}"
		else
			showname = ""
			#puts "\n\nNo Show Title Found: Assuming Episode Title as Show Title."
			#title_swap = true
			#showname = removeCredits(parts, endind+1, creditStrings, params.debug)
		end
		showname = showname.strip.titlecase
		
		
		puts "\nDetected Showname: " + showname if params.debug
		print "Episode Number Data: " if params.debug
		print season, "x", ep if params.debug

		
		showname = (params.prepend_showname||"") + showname + (params.append_showname||"")
		showname = params.replace_showname if params.replace_showname != nil
		showname = showRename(showname)

		puts "\nFinal Showname: " + showname if params.debug
		puts "\n" if params.debug
		
		

		puts "Searching for Episode Name" if params.debug
		
		#if we actually found the seasion and episode numbers
		if season.to_i != 0 and ep.length != 0
		
		
			#move 'the' to the end and if there is a colon as in 
			#"Star Trek: The Next Generation", split it up into 
			#"Star Trek" and "The Next Generation" so that the directory
			#path is ... /Star Trek/The Next Generation/Season ...
			showPath = showname.TheToEnd
			showPath = showPath.split(":").map{|word| word.strip}
		
		
			eptitle = ""
			#build the episode title, unless we're stripping it out
			unless params.no_title # or title_swap
		
				endind += 1	
				eptitle = removeCredits(parts, endind, creditStrings, params.debug)

				eptitle = eptitle.strip.titlecase
				
				if eptitle == ""
					episodes = getEpisodeTitles(showname)
					eptitle = episodes[[season.to_i, ep[0].to_i]]
					if eptitle == nil eptitle = ""
				end
				
				
				puts "Final Episode Name: " + eptitle if params.debug				
			end
			
			puts "File Extension: " + file_ext if params.debug
			
			newdir, newname = makeNewNames(params.source, params.target, params.no_move, showname, showPath, eptitle, season, ep, file_ext)
			
			return true, newdir, newname, showname, season, ep
			
		else
			return false
		end

end














####################################################
# Read/Write config files to/from data scructures
####################################################

def loadFileExtensions()

	return loadStringList(configfile("indexer-exts")).map{|ext| ext.downcase}

end


def loadCreditStrings()

	return (loadFileExtensions + loadStringList(configfile("indexer-credits")))#.map{|credit| credit.upcase}

end


def loadSegments

	loadMap(configfile("show-segments"))

end


def setShowSegment(show, segment)

	segments = loadSegments
	segments[show] = segment

	writeMap(configfile("show-segments"), segments)

end


def hasSegment?(show)

	loadSegments.include? show

end


def getRenameMap()
	loadMap(configfile("show-rename"))
end


def showRename(show)

	rename = getRenameMap
	
	return rename[show] if hasRename? show
	return show
	

end


def addRename(show, newshow)

	map = getRenameMap
	map[show] = newshow
	writeMap(configfile("show-rename"), map)

end

def hasRename?(show)
	getRenameMap.include? show
end







##############################################
# Utilities
##############################################

def loadStringList(filename)

	`cat "#{filename}"`.strip.split("\n")

end

def addStringToList(filename, string)
	`echo "#{string}" >> #{File.dirname(__FILE__) + "/" + filename}`
end

def loadMap(file)

	strings = loadStringList(file)
	segments = {}
	
	while (strings.length >= 2)
		show = strings.shift
		segment = strings.shift
		segments[show] = segment
	end
	
	return segments

end

def writeMap(file, map)

	File.open(file, "w"){|fh|
	
		map.each{|k, v|
			fh.puts k
			fh.puts v
		}
	
	}

end

def configfile(file)
	File.dirname(__FILE__) + "/" + file
end


def geturl(url)
	`wget -U "Mozilla/5.0 (Windows; U; Windows NT5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+" -O - "#{url}"`
end

show = ARGV[0]

def getEpisodeTitles(show)

	epguidepage = geturl("http://www.google.com/search?q=site:epguides.com #{show}&btnI")
	csvurl = epguidepage[/http:\/\/epguides.com\/common\/exportToCSV.asp\?rage=[0-9]*/]
	csvpage = geturl(csvurl)

	csv = csvpage.strip.split("\n")[7..-4].map{|line| line.strip }

	episodelist = csv.map{|line| 

		parts = line.split ",", 6
		season = parts[1].to_i
		ep = parts[2].to_i
		title = parts[5].reverse.split(",", 2)[1].reverse[1..-2]
		
		[[season, ep], title]

	}
	
	episodes = {}
	episodelist.each{|ep| episodes[ep[0]] = ep[1]}

	return episodes	
	
end
