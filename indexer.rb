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


require File.dirname(__FILE__)+'/indexer-functions.rb'


def doIndexing params

	
	fileExtensions = loadFileExtensions
	creditStrings = loadCreditStrings
	showSegments = loadSegments
	
	if params.targetfile == nil
		#get a list of all files that match our file extensions
		list = findFilesWithExtensions(params.source)
	else
		list = [params.targetfile]
	end
	
	shownames = []
	hashlist = []

	failcount = 0
	successcount = 0
	reallymove = false
	reallyhash = false

	puts "List of files to consider:\n", list if params.debug

	list.each{|name|

		parsed, newdir, newname, showname, season, ep = parseFilename(name, creditStrings, params)

		if parsed

			shownames << showname
						
			if params.hashonly
			
				
				if not params.simulate
					md5result = `ionice -c 3 md5sum "#{params.source}#{name.chomp}"`
				else
					md5result = "---------SIMULATION--------- #{name.chomp}\n"
				end
				
				puts "\nHASHED \t\"#{name.chomp}\"\n TO \t\"#{md5result.split(" ")[0]}\" ..."
				hashlist << [showname + " - Season " + season, md5result]
				
			else
			
				if File.exists? newname then
					puts "NOT MOVING FILE: #{name}\nTARGET: #{newname} ALREADY EXISTS"
					failcount += 1
				else
				
					puts "\nMOVING \t\"#{name.chomp}\"\n TO \t\"#{newname}\" ..."

					if not params.simulate
					
						reallymove = true
					
						`mkdir -p '#{newdir}'`
						`ionice -c 3 mv "#{params.source}#{name.chomp}" "#{newname}"`
					end
					successcount += 1
				
				end
				
			end
			
		else
		
			newdir, newname = parseFilenameMovie(name, creditStrings, params)
			
			puts newname if params.debug
			
			shownames << newname
			
			if File.exists? newname then
				puts "NOT MOVING FILE: #{name}\nTARGET: #{newname} ALREADY EXISTS"
				failcount += 1
			else
			
				puts "\nMOVING \t\"#{name.chomp}\"\n TO \t\"#{newname}\" ..."

				if not params.simulate
				
					reallymove = true
				
					`mkdir -p '#{newdir}'`
					`ionice -c 3 mv "#{params.source}#{name.chomp}" "#{newname}"`
				end
				successcount += 1
			
			end
			
			#failcount += 1			
		end


	}
	
	#if we're just doing hashing and we managed to process at least one file...
	if params.hashonly and shownames.size > 0 then
		
		hashes = hashlist.map{|pair| showname, hash = pair; hash}
		names = hashlist.map{|pair| showname, hash = pair; showname}
		
		#if these shows names are all the same, we can safely give the
		#hash file a more descriptive name
		filename = ""
		filename = names[0] + " - " if names.uniq.size == 1
		
		File.open(params.target + "/.Hashes/" + filename + "Hashes.md5", "w"){|fh| fh << hashes.join("")}
		
		reallyhash = true
		
	end

	#print summary	
	puts "\n*************************************"
	puts "* SHOWS INCLUDED                    *"
	puts "*************************************"
	puts shownames.uniq
	puts "*************************************\n"
	puts "#{successcount} Succeeded, #{failcount} Failed" unless params.hashonly
	puts "\n"
	
	#completion notification
	if reallymove and not params.no_move
		`notify-send --icon=video "Indexing Complete" "#{successcount} Succeeded, #{failcount} Failed\n\n#{shownames.uniq.inject(){|str, item| str + "\n" + item}}"`	
	elsif reallyhash
		`notify-send --icon=gtk-execute "Hash Complete"`
	elsif successcount == 0 and failcount > 0
		`notify-send --icon=dialog-error "Indexing Failed" "Failed to index any files"`
	end
	
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

allowedArgs = ["--debug", "--simulate", "--rename-only", "--strip-title", "--prepend-name", "--append-name", "--replace-name", "--source-folder", "--target-folder", "--hash-only", "--file"]

#Parameters for the execution of the programme
params = Params.new()


args = ARGV
argParts = args.map{|arg| arg.split("=", 2)}

#check for unknowns -- abort if present
argTitles = argParts.map{|arg| arg[0]}
argTitles.each{|title| error("Unrecognized Argument: #{title}", allowedArgs) if not allowedArgs.include?(title) }

#get the argument values
params.debug = args.include? "--debug"
params.simulate = args.include? "--simulate"
params.hashonly = args.include? "--hash-only"
params.no_move = args.include? "--rename-only"
params.no_title = args.include? "--strip-title"
params.lookup_replace_showname = args.include? "--lookup-replace-name"
params.prepend_showname = getArgValue(argParts, "--prepend-name")
params.append_showname = getArgValue(argParts, "--append-name")
params.replace_showname = getArgValue(argParts, "--replace-name")
params.source = getArgValue(argParts, "--source-folder") || "./"
params.target = getArgValue(argParts, "--target-folder") || defaultTarget

if getArgValue(argParts, "--file") != nil
	targetfile = getArgValue(argParts, "--file")
	params.targetfile = File.basename(targetfile) #+ "." + File.extname(targetfile)
	params.source = File.dirname(targetfile) + "/"
	params.source = params.source[7..-1] if params.source[0..6] == "file://"
end

puts "\nRunning in: #{params.source}"

#only do the work once we have the lockfile
File.open(configfile("lockfile"), "w"){|f|

	f.flock(File::LOCK_EX)
	doIndexing(params)
	
}


puts "Done"

