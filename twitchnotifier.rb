require 'json'
require 'open-uri'

# $game      - name of game
# $viewers   - number of viewers watching the stream
# $mature    - true or false indicating whether the channel is in mature mode
# $status    - channel status
# $language  - broadcaster language
# $name      - broadcaster name
# $url       - url to the stream
# $followers - amount of followers the channel has

# $color_default
# $color_black
# $color_red
# $color_green
# $color_yellow
# $color_blue
# $color_magenta
# $color_cyan
# $color_lgray
# $color_dgray
# $color_lred
# $color_lgreen
# $color_lyellow
# $color_lblue
# $color_lmagenta
# $color_lcyan
# $color_white

#   -- makeChannelString --
# Applies each of the above variables to a string from a stream object
#  given to us from the twitch API
def makeChannelString(format, stream)
	game      = stream['game']
	viewers   = stream['viewers'].to_s
	mature    = stream['channel']['mature'].to_s
	status    = stream['channel']['status']
	language  = stream['channel']['broadcaster_language']
	name      = stream['channel']['display_name']
	url       = stream['channel']['url']
	followers = stream['channel']['followers'].to_s

	output = format
	#variables
	output.gsub! /\$game/, game
	output.gsub! /\$viewers/, viewers
	output.gsub! /\$mature/, mature
	output.gsub! /\$status/, status
	output.gsub! /\$language/, language
	output.gsub! /\$name/, name
	output.gsub! /\$url/, url
	output.gsub! /\$followers/, followers

	#colors
	output.gsub! /\$color_default/,  "\e[39m"
	output.gsub! /\$color_black/,    "\e[30m"
	output.gsub! /\$color_red/,      "\e[31m"
	output.gsub! /\$color_green/,    "\e[32m"
	output.gsub! /\$color_yellow/,   "\e[33m"
	output.gsub! /\$color_blue/,     "\e[34m"
	output.gsub! /\$color_magenta/,  "\e[35m"
	output.gsub! /\$color_cyan/,     "\e[36m"
	output.gsub! /\$color_lgray/,    "\e[37m"
	output.gsub! /\$color_dgray/,    "\e[90m"
	output.gsub! /\$color_lred/,     "\e[91m"
	output.gsub! /\$color_lgreen/,   "\e[92m"
	output.gsub! /\$color_lyellow/,  "\e[93m"
	output.gsub! /\$color_lblue/,    "\e[94m"
	output.gsub! /\$color_lmagenta/, "\e[95m"
	output.gsub! /\$color_lcyan/,    "\e[96m"
	output.gsub! /\$color_white/,    "\e[97m"

	output
end

def sendNotification(message)
	`notify-send "#{message}"` # wow such good practice
end

#   -- outputFormat --
# returns the string in format.txt if format.txt exists with each empty line and line starting with a # removed
# if format.txt doesn't exist returns a default format
def outputFormat
	if File.exists? 'format.txt'
		return File.readlines('format.txt').reject { |e| e.start_with? '#' or e.chomp.empty? }.join("\n")
	end
	return '$name is playing $game for $viewers viewers'
end

#   -- readCurrentChannels() --
# Reads each line from channels.txt into an array
# Removes trailing characters from each channel
# Converts each channel to lowercase
# Removes duplicates
# Returns the resulting array
def readCurrentChannels()
	File.readlines('channels.txt').map{ |e| e.chomp.downcase }.uniq
end

#   -- writeChannels --
# Chomps trailing characters from channels
# Converts every channel in channels to lowercase
# Removes duplicates
# Joins them all together into a single string seperated by newlines
# Writes the resulting string to channels.txt
def writeChannels(channels)
	return if not channels.is_a? Array
	File.write('channels.txt', channels.map{ |e| e.chomp.downcase }.uniq.join("\n"))
end

#   -- delete --
# Reads the current channels into an array from readCurrentChannels()
# Deletes every channel from the list which is contained in the channels
#  parameter
# Writes the resulting array back into channels.txt
def delete(channels)
	return if not channels.is_a? Array #meh
	curChannels = readCurrentChannels()
	curChannels.reject! { |e| channels.include? e.downcase }
	writeChannels(curChannels)
end

#   -- add --
# Reads the current channels into an array from readCurrentChannels()
#  and adds each of the channels defined in the channels parameter to it,
#  then writes the result back out to channels.txt
def add(channels)
	return if not channels.is_a? Array #meh
	curChannels = readCurrentChannels
	curChannels += channels
	writeChannels(curChannels)
end

@oldOnlineChannels = []
def checkNewChannels(channelData)
	channelNames = []
	newOnline = []

	channelData['streams'].each do |cd|
		channelNames << cd['channel']['display_name'].downcase
	end

	newChannels = channelNames.reject { |e| @oldOnlineChannels.include? e }
	@oldOnlineChannels = channelNames
	newChannels
end

def requestChannels(channels)
	website = open("https://api.twitch.tv/kraken/streams?channel=#{channels.join(',')}")
	channelData = JSON.parse(website.read)
	website.close
	return channelData
end

#   -- getOnlineChannels --
# Makes a GET request to the endpoint /kraken/streams of the twitch api
#  with the parameter channel.
# Channel is a comma seperated list of channels to query.
# The GET returns a JSON formatted string which contains all the channels
#  which are live from the channels parameter and information about the channels.
# It then creates a formatted string from each stream with either the default format
#  specified in outputFormat() or the format contained in format.txt
def getOnlineChannels(channelData)
	result = []
	channelData['streams'].each do |stream|
		result << makeChannelString(outputFormat(), stream)
	end
	result
end

if not File.exists? 'channels.txt'
	f = File.open 'channels.txt', 'w' 
	f.close
end

if ARGV.size == 0
	# When running the script with no args print the formatted version of
	# all of the online channels
	oldStreams = []
	loop do
		print "\e[H\e[2J"
		channelData = requestChannels(readCurrentChannels())
		formatted = getOnlineChannels(channelData)
		puts formatted

		newChans = checkNewChannels(channelData)
		newChans.each do |e|
			sendNotification("#{e} is now streaming!")
		end
		sleep 30
	end
else
	command = ARGV[0].downcase

	# If there are any args, assume the first arg is a command
	# Possible commands:
	#         add - Add a channel to the channels.txt with no duplicates
	#         delete - Delete a channel from channels.txt if it exists
	#         list - Print all the channels in channels.txt unformatted
	if command == 'add'
		puts "Adding #{ARGV[1..-1].size} channels"
		add(ARGV[1..-1])
	elsif command == 'delete'
		puts "Deleting #{ARGV[1..-1].size} channels"
		delete(ARGV[1..-1])
	elsif command == 'list'
		puts readCurrentChannels
	end 
	puts "Done"
end
