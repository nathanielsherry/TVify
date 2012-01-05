#!/usr/bin/ruby

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


require File.dirname(__FILE__)+'/support.rb'

def getTVFileInformation(filename, credits, debug)

	filename, fileext = removeFileExt(filename)

	patterns = [
	
		#***double episode matchings***
	
		"[Ss]([0-9]{1,2})[Ee]([0-9]{1,2})[Ee]([0-9]{1,2})",				#eg S01E01E02
		"[Ss]([0-9]{1,2})[Ee]([0-9]{1,2})([0-9]{1,2})",					#eg S01E0102
		"([0-9]{1,2})[xX]([0-9]{1,2})[-x]([0-9]{1,2})",					#eg 1x01-02
		"([0-9]{1,2})[xX]([0-9][0-9])([0-9][0-9])",						#eg 1x0102
		
		#***single episode matchings***
		
		"[Ss]([0-9]{1,2})[Ee]([0-9]{1,2})",								#eg S01E01
		"([0-9]{1,2})[xX]([0-9]{1,2})",									#eg 1x01
		"\\[([0-9]{1,2})[xX]([0-9][0-9])\\]",								#eg [1x01]
		"(0[0-9])([0-9][0-9])",											#eg 0101 - clashes with years - eg Doctor Who 2005, so only works with seasons starting in 0
		"([0-9])([0-9][0-9])",											#101
		"([0-9]{1,2})\\.([0-9]{1,2})",									#01.01
		"Season ([0-9]{1,2}),*[ ]+Episode ([0-9]{1,2})",				#Season 1, Episode 1
	]
	
	
	p filename
	
	patterns.each{|pattern|
	
		epcodeRegex = Regexp.new pattern
		showRegex = Regexp.new "(.*?)[ -\\.]*(#{pattern.gsub("(", "").gsub(")", "")})[ -\\.]*(.*)"
		

		p showRegex

		#showname, title
		showParts = showRegex.match(filename).to_a
		next if showParts == []
		p showParts

		showParts.shift
		show = cleanName showParts.shift
		epcode = showParts.shift
		title = removeCredits( cleanName(showParts.shift), credits, debug)
		
		#episode code
		ep = []
		epParts = epcodeRegex.match(epcode).to_a
		next if epParts == []
		
		epParts.shift
		season = epParts.shift
		ep = epParts

		ep.map!{|epnum| 
			if epnum.length == 1 then
				epnum = "0" + epnum
			end
			epnum
		}

		
		
		return show, season, ep, title, fileext
	
	}
	
	return nil, nil, nil, nil, nil

end



#takes a list of title parts, a start index, and a list of credit strings
#looks through list until it finds
def removeCredits(title, credits, debug)

	parts = title.split " "
	title = ""

	parts.each{|part|
	
		part = part.chomp.strip
	
		ended = false	
		ended = credits.map{|credit| part[0..credit.size-1] == credit}.inject(false){|a,b| a or b}
		
		puts "Found Title Fragment: #{part}" if (not ended) and debug
		puts "Title Ended Search on: #{part}" if ended and debug
		return title if ended
	
		title += " " if title != ""
		title += part
	
	}
	
=begin
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
=end
	return title

end


def cleanName(name)

	parts = name.split(/[ ._]/)	
	return parts.join(" ").strip.titlecase

end

def removeFileExt(name)

	parts = name.split "."
	return parts[0..-2].join("."), parts[-1]

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
	
	name, file_ext = removeFileExtension name
	
	title = removeCredits(name, creditStrings, params.debug)
	
	p title
	
	newdir, newname = makeNewNames(params.source, params.target, params.no_move, title, nil, nil, nil, nil, file_ext)
	
	return newdir, newname
	
	
end


def parseFilename(name, creditStrings, params)


		puts "\n\n\nExamining " + name
=begin
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
=end
	
		showname, season, ep, eptitle, file_ext = getTVFileInformation name, creditStrings, params.debug
		return false if showname == nil
		
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
		
		
			#build the episode title, unless we're stripping it out
			unless params.no_title # or title_swap
		


					episodes = getEpisodeTitles(showname)
					if episodes != nil
						neweptitle = episodes[[season.to_i, ep[0].to_i]]
						eptitle = neweptitle if neweptitle != nil 
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

def getEpguideURL(show)
	loadMap(configfile("show-epguideurl"))[show]
end

def setEpguideURL(show, url)
	map = loadMap(configfile("show-epguideurl"))
	map[show] = url
	writeMap(configfile("show-epguideurl"), map)
end


def resolveEpguideURL(show)

	url = getEpguideURL(show)
	return url if url != nil
	
	epguidepage = geturl("http://www.google.com/search?q=site:epguides.com #{show}&btnI")
	url = epguidepage[/http:\/\/epguides.com\/common\/exportToCSV.asp\?rage=[0-9]*/]
	
	setEpguideURL(show, url) if url != nil
	return url

end

def getEpisodeTitles(show)


	cvsurl = resolveEpguideURL(show)
	return nil if cvsurl == nil
	
	csvpage = geturl(cvsurl)
		
	csv = csvpage.strip.split("\n")[7..-4].map{|line| line.strip }

	episodelist = csv.map{|line| 


		parts = line.split ",", 7

		season = parts[1].to_i
		ep = parts[2].to_i
		title = parts[5][1..-2]#.reverse.split(",", 2)[1].reverse[1..-2]
		
		[[season, ep], title.gsub("/", "\\")]

	}
	
	episodes = {}
	episodelist.each{|ep| episodes[ep[0]] = ep[1]}

	return episodes	
	
end








##############################################
# Utilities
##############################################

def loadStringList(filename)

	list = []

	File.open(filename, "r"){|f|
		f.flock(File::LOCK_EX)
		f.each_line{|l| list << l.strip}
	}
	return list

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
		fh.flock(File::LOCK_EX)
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
	page = `wget -U "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.A.B.C Safari/525.13" -O - "#{url}"`
	return page.encode("US-ASCII", :invalid => :replace, :undef => :replace, :replace => "")
end
