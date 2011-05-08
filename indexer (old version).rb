#!/usr/bin/ruby1.9

require File.dirname(__FILE__)+'/indexer-functions.rb'


def doIndexing debug=false, simulate=false, no_move=false, no_title=false, prepend_showname=nil, append_showname=nil, replace_showname=nil, source="./", target="./", hashonly=false

	
	fileExtensions = ["avi", "mkv", "mpg", "divx", "mp4"]
	creditStrings = fileExtensions.map{|ext| ext.upcase} + ["[DD]", "LOL", "WS", "DIVX", "720P", "HDTV", "(HDTV", "WS", "PDTV", "XVID", "REPACK", "PROPER", "DSR", "PREAIR", "(BO)", "READINFO", "[DIGITALDISTRACTIONS]", "DVDRIP", "[DIVX", "[MM]", "(TV)", "[XVID]", "[PDTV]"]
	
	list = fileExtensions.map{|ext| `ls "#{source}" | grep -i .#{ext}$`.split("\n")}.inject :+
	shownames = []
	hashlist = []

	puts list if debug

	list.each{|name|

		puts "\n\n\nExamining " + name if debug

		season = 0
		ep = []
		endind = -1
		title_swap = false

		#split up the file name into parts
		parts = splitTitleToParts(name)
		puts "PARTS:\n" + parts.map{|p| "\t"+p+"\n"}.join("") if debug
		file_ext = parts.last.strip

		#find the part that matches the episode number. Everything before this is the show title.
		#everything after it is Episode Title, Credits, File Ext
		parts.each_with_index{|part, index|

			endind, season, ep = matchEpisodeNumber(part, index, debug)
			
			break if endind != nil

=begin
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
				endind = index
				break
			end

			#eg S01E0102
			match = part =~ /[Ss][0-9].?[Ee][0-9][0-9][0-9][0-9]/
			if match == 0
				season = part[part.index(/[Ss]/) + 1, part.index(/[Ee]/)-1]
				e_ind = part.index(/[Ee]/)
				ep << part[part.index(/[Ee]/) + 1, 2]
				ep << part[part.index(/[Ee]/) + 3, 2]
				endind = index
				break
			end
			
			#INTERNAL FORMAT
			#eg 1x01-02
			#alternate matches 01x01x02
			match = part =~ /[0-9][0-9]?[xX][0-9][0-9]?[-x][0-9][0-9]?/
			if match == 0
				sep = part.downcase.split("x", 2)
				
				season = sep[0]
				ep = sep[1].split(/[-x]/)
				endind = index
				break
			end

			#eg 1x0102
			match = part =~ /[0-9][0-9]?[xX][0-9][0-9][0-9][0-9]?/
			if match == 0
				sep = part.downcase.split "x"
				
				season = sep[0]
				ep << sep[1][0,2]
				ep << sep[1][2,2]
				endind = index
				break
			end

			#***single episode matchings***
			#eg S01E01
			match = part =~ /[Ss][0-9].?[Ee][0-9].?/
			if match == 0
				season = part[part.index(/[Ss]/) + 1, part.index(/[Ee]/)-1]
				ep << part[part.index(/[Ee]/) + 1..-1]
				endind = index
				break
			end
			
			#INTERNAL FORMAT
			#eg 1x01
			match = part =~ /[0-9][0-9]?[xX][0-9][0-9]?/
			if match == 0
				sep = part.downcase.split "x"
				
				season = sep[0]
				ep << sep[1]
				endind = index
				break
			end
			
			#eg 101
			match = part =~ /[0-9][0-9][0-9]?/
			if match == 0 and part.strip.length == 3
				season = part[0,1] if part.length == 3
				season = part[0..1] if part.length == 4
				ep << part[-2..-1]
				endind = index
				break
			end
			
			#eg [1x01]
			#todo: cant this merge with the one avobe using '\[?' ?
			#parsing would get more complicated, but...
			match = part =~ /\[[0-9][0-9]?[xX][0-9][0-9]\]?/
			if match == 0
				sep = part[1..-2].downcase.split "x"
				season = sep[0]
				ep << sep[1]
				endind = index
				break
			end

=end
		}

		#pad episode numbers (not season numbers) with 0s
		ep = ep.map{|e| e.size == 1 ? "0" + e  : e}

		#if there was a title, join all the parts with spaces
		#if there was no title, we assume that the title has been placed after the episode number by some poor misguided fool.
		puts endind
		if endind != 0
			showname = "#{parts[0..endind-1].join(" ")}"
		else
			puts "No Show Title Found: Assuming Episode Title as Show Title."
			title_swap = true
			showname = removeCredits(parts[1..-2]).join(" ")
		end
		showname = showname.strip.titlecase

		puts "\nDetected Showname: " + showname if debug
		print "Episode Number Data: " if debug
		print season, "x", ep if debug

		showname = (prepend_showname||"") + showname + (append_showname||"")
		showname = replace_showname if replace_showname != nil

		puts "\nFinal Showname: " + showname if debug
		puts "\n" if debug
		
		
		puts "Searching for Episode Name" if debug
		
		#if we actually found the seasion and episode numbers
		if season.to_i != 0 and ep.length != 0
		
		
			#move 'the' to the end and if there is a colon as in 
			#"Star Trek: The Next Generation", split it up into 
			#"Star Trek" and "The Next Generation" so that the directory
			#path is ... /Star Trek/The Next Generation/Season ...
			showPath = showname.TheToEnd
			showPath = showPath.split(":").map{|word| word.strip}
		
		
			title = ""
			#build the episode title, unless we're stripping it out
			unless no_title
		
				endind += 1	
				title = removeCredits(parts, endind, creditStrings)
				
=begin		
				
				while true
				
					
					break if endind >= parts.size
					newpart = parts[endind].chomp.strip
					ended = false
					creditStrings.each{|string| ended = true if newpart.upcase[0..string.size-1] == string}
					puts "Found Title Fragment: #{newpart}" if (not ended) and debug
					puts "Title Ended Search on: #{newpart}" if ended and debug
					break if ended

					title += parts[endind].strip + " " if parts[endind].size > 0
					endind += 1
				end
				
=end

				title = title.strip.titlecase
				puts "Final Show Name: " + title if debug
				
			end
			
			shownames << showname
			
			newdir = target + "#{showPath.join("/")}/Season #{season.to_i}/"
			newdir = source if no_move
			newname = "#{newdir}#{showname} - #{season.to_i}x" +  ep.join("-")
			newname += " - #{title}" if title != ""
			newname += "." + file_ext
			
			if hashonly
				
				if not simulate
					md5result = `ionice -c 3 md5sum "#{source}#{name.chomp}"`
				else
					md5result = "---------SIMULATION--------- #{name.chomp}\n"
				end
				
				puts "\nHASHED \t\"#{name.chomp}\"\n TO \t\"#{md5result.split(" ")[0]}\" ..."
				hashlist << [showname + " - Season " + season, md5result]
				
			else
			
				puts "\nMOVING \t\"#{name.chomp}\"\n TO \t\"#{newname}\" ..."

				if not simulate
					`mkdir -p '#{newdir}'`
					`ionice -c 3 mv "#{source}#{name.chomp}" "#{newname}"`
				end
				
			end
			
		end

	}
	
	if hashonly then
		
		hashes = hashlist.map{|pair| showname, hash = pair; hash}
		names = hashlist.map{|pair| showname, hash = pair; showname}
		
		#if these shows names are all the same, we can safely give the
		#hash file a more descriptive name
		filename = ""
		filename = names[0] + " - " if names.uniq.size == 1
		
		File.open(target + "/.Hashes/" + filename + "Hashes.md5", "w"){|fh| fh << hashes.join("")}
		
	end

	puts "\n*************************************"
	puts "* SHOWS INCLUDED                    *"
	puts "*************************************"
	puts shownames.uniq
	puts "*************************************\n\n"
	
	
end

def error(message, allowedArgs)

	puts "", message, "", "Allowed Arguments:"
	allowedArgs.each{|arg| puts "\t" + arg}
	exit -1

end

def getArgValue(argPairs, arg)

	argPairs.each{|pair|
	
		if pair[0] == arg
			return pair[1]
		end
	
	}
	
	return nil

end

allowedArgs = ["--debug", "--simulate", "--rename-only", "--strip-title", "--prepend-name", "--append-name", "--replace-name", "--source-folder", "--target-folder", "--hash-only"]

args = ARGV
argParts = args.map{|arg| arg.split("=", 2)}

#check for unknowns -- abort if present
argTitles = argParts.map{|arg| arg[0]}
argTitles.each{|title| error("Unrecognized Argument: #{title}", allowedArgs) if not allowedArgs.include?(title) }

#get the argument values
debug = false
debug = args.include? "--debug"

simulate = false
simulate = args.include? "--simulate"

hashonly = false
hashonly = args.include? "--hash-only"

noMove = false
noMove = args.include? "--rename-only"

noTitle = false
noTitle = args.include? "--strip-title"

prepend = nil
prepend = getArgValue(argParts, "--prepend-name")
append = nil
append = getArgValue(argParts, "--append-name")
replace = nil
replace = getArgValue(argParts, "--replace-name")

source = getArgValue(argParts, "--source-folder") || "./"
target = getArgValue(argParts, "--target-folder") || "./"

puts "\nRunning in: #{source}"

doIndexing(debug, simulate, noMove, noTitle, prepend, append, replace, source, target, hashonly)


puts "Done"

