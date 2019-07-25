require 'sinatra'
require 'redis'
require 'pry'
require 'treat'
require 'engtagger'

set :port, 3000

#configuring server to enable cors from any request
configure do
    enable :cross_origin
  end
  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

redis = Redis.new
filename = 'dictionary.txt'

helpers do
	def key(word)
		# downcase so that proper nouns are stored under the same key e.g. 'Ash' stored under key 'ahs' as separate member from 'ash'
		word.downcase.split('').sort.join
	end
	#  helper to parse the request body and return an error to the client if the parsing fails
	def json_params
		begin
			@body = JSON.parse(request.body.read)
		rescue
			halt 400, { message:'Invalid JSON' }.to_json
		end
	end
end

#  populates redis with all words from dictionary
post '/dictionary.json' do
	File.open(filename, 'r') do |f|
		f.each_line do |line|
			word = line.gsub("\n","")
			# SADD adds members to set stored at key
			# set is unique so if member already exists, then it is ignored
			# if the key does not exist, then a new set is created and members are added into it
			redis.sadd(key(word), word)
		end
		status 201
	end
end

# adds array of words to redis
post '/words.json' do
	json_params

	# checks JSON has correct key
	if !@body['words']
		return status 422
	else
		@body['words'].each do |word|
			redis.sadd(key(word), word)
		end
		status 201
	end
end

# returns array of words that are anagrams of the word passed
# respects query param for whether or not to include proper nouns in the list of anagrams
get '/anagrams/:word.json' do
	word = params['word']
	proper_noun_flag = params['proper_nouns']
	limit = params['limit']

	anagrams = redis.smembers(key(word)) - [word]

	def filter_proper_nouns(anagrams)
		anagrams.each do |anagram|
			first_char = anagram[0]
			anagrams.delete(anagram) if (anagram.category === 'noun' && !!(/[[:upper:]]/.match(first_char)))
		end
	end

	if limit
		if proper_noun_flag == 'false'
			filter_proper_nouns(anagrams)
			anagrams = anagrams.sample(limit.to_i)
		end
		# returns random subset (faster than retrieving the whole set)
		anagrams = redis.srandmember(key(word), limit.to_i) - [word] if (proper_noun_flag != 'false')
	elsif proper_noun_flag == 'false'
		filter_proper_nouns(anagrams)
	else
		anagrams 
	end
	{ anagrams: anagrams }.to_json
end

# takes a set of words and returns whether or not they are all anagrams of each other
get '/anagram.json' do
	json_params

	if !@body['words']
		return status 422
	else
		array = []
		@body['words'].each do |word|
			sorted = key(word)
			array.push(sorted)
		end
		if array.uniq.length == 1
			{ anagrams: true }.to_json
		else
			{ anagrams: false }.to_json
		end
	end
end

# deletes a single word
delete '/words/:word.json' do
	word = params['word']
	redis.srem(key(word), word)
	status 204
end

# deletes a word and all of its anagrams
delete '/anagrams/:word.json' do
	word = params['word']
	redis.del(key(word))
	status 204
end

# deletes all contents from redis
delete '/words.json' do
	redis.flushall
	status 204
end

# returns a count of words and min/max/median/average word length
get '/words/metrics.json' do
	all_keys = redis.keys("*")
	all_members = []

	# not the most performant as this calls redis for every key
	all_keys.each do |key|
		members = redis.smembers(key)
		# creates new array
		all_members.concat members
	end

	@shortest_length = all_members.min_by(&:length).length
	@longest_length = all_members.max_by(&:length).length
	@word_count = all_members.length
	sorted = all_members.sort_by(&:length)
	len = sorted.length
	@median_length = (sorted[(len - 1) / 2] + sorted[len / 2]).length / 2.0
	@average_length = all_members.join.size / all_members.size.to_f

	{ word_count: @word_count, anagram_min_length: @shortest_length, anagram_max_length: @longest_length, anagram_median_length: @median_length, anagram_average_length: @average_length }.to_json	
end

# returns words with the most anagrams
get '/words/top.json' do
	# doesn't return multiple if there is a tie
	top_key = redis.keys("*").max_by() { |key| redis.scard(key) }
	most_anagrams = redis.smembers(top_key)
	{ most_anagrams: most_anagrams }.to_json
end

# returns all anagram groups  of size >= *x*
get '/anagramsby/:size.json' do
	wordsize = params['size'].to_i
	all_keys = redis.keys('*')
	anagrams = []
	all_keys.each do |key|
		if key.length >= wordsize
			anagrams.push(redis.smembers(key))
		end
	end
	# return 200 OK if request successful with empty array
	# 204 used for server not needing to return anything e.g delete
	# 404 used for nothing found that matched the request URI
	{ anagrams: anagrams }.to_json
end

# options that can be set to control where requests are able to come from
# can also control which requests are possible
options "*" do
    response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
  end
