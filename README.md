# Anagram API
###### Fast searches for anagrams


## Design Choices


While I didn't have prior experience with Sinatra, I did choose to it as a framework for this API. It is easy to setup and makes it quick to develop a proper RESTful API that accepts and returns JSON. As this is a project for fast anagram searches, I wanted to keep the framework lean so I could focus on implementing fast searching. For these reasons I chose Sinatra over a Rails API-only app.

I chose Redis as a choice of data store to help with posting words and retrieving anagrams fast. The contents of the dictonary are stored as keys and values in the memory of the local machine. This is fine since this is a very small project, but could be too big of a tradeoff for a larger scale project. Also, since Redis is used as a NoSQL database it is quick to set up; no schemas have to be defined. Since there are no data types enforced though there is potential for issues with data integrity, as characters other than alphanumeric a-z can be stored.

The proper noun parameter for /GET anagrams required consideration for how to detect proper nouns. Simply checking for words with a capital first letter isn't sufficient since (1) non-proper-nouns can be stored with capital first letters and (2) capitalized words exist in the dictionary that are not proper nouns anyway. An adjective example of this is 'Achariaceous'. Even the NLP frameword Treat used in this project mistakes this adjective as a noun -  'Achariaceous'.category returns 'noun'. The endpoint would mistake that as a pronoun because I am checking for nouns that have a capital first letter. I thought however, that this was a fairly decent initial test for proper nouns. 'louisville'.category returns 'unknown' whereas 'Luisville'.category returns 'noun'. Also it recognizes 'Harmless' as an adjective even thought the first letter is capitalized. Clearly Treat applies many tests to words, such as these endings for adjectives:

-able/-ible understandable, capable, readable, incredible
-al mathematical, functional, influential, chemical
-ful beautiful, bashful, helpful, harmful
-ic artistic, manic, rustic, terrific
-ive submissive, intuitive, inventive, attractive
-less sleeveless, hopeless, groundless, restless
-ous gorgeous, dangerous, adventurous, fabulous



## Setting Up and Testing

```
# Install
brew install ruby
brew install sinatra
brew install redis
gem install treat
gem install engtagger
```

```
# Install dependencies
bundle
```

```
# Start the sinatra server
ruby server.rb
```

```
# Start the redis server
redis-server
```

```
# Run the provided suite of tests
{bash}
ruby anagram_test.rb
```

- `POST /dictionary.json`: populates data store with words from dictionary
- `POST /words.json`: Takes a JSON array of English-language words and adds them to the corpus (data store).
- `GET /anagrams/:word.json`:
  - Returns a JSON array of English-language words that are anagrams of the word passed in the URL.
  - This endpoint should support an optional query param that indicates the maximum number of results to return.
- `DELETE /words.json`: Deletes all contents of the data store.
- `DELETE /words/:word.json`: Deletes a single word from the data store.
- `DELETE /anagrams/:word.json`: Deletes a word and all of its anagrams from the data store.
- `GET /anagram.json`: Takes a set of words and returns whether or not they are all anagrams of each other.
- `GET /words/metrics.json`: Returns a count of words and min/max/median/average word length
- `GET /words/top.json`: Returns words with the most anagrams
- `GET /anagramsby/:size.json`: Returns all anagram groups  of size >= *x*



## Additional Features

**Enhancements to Develop**
Natural Language Processing
It is complex to develop a complete NLP system, but it could be very useful for better identifying various types of words.

Filtering for certain types of anagrams
Users could further limit the types of word from consuming the /GET anagrams endpoint. They could ask to get back verbs only, adverbs, and any other part of speech category of word.

Rewrite /GET anagrams in Python
Python is a strong language for NLP. It seems like it would be a stronger technology choice for language processing than Ruby.

Error Handling
If a UI was consuming this endpoint, I would add additional error handling messages, such as an error message for trying to delete a word that does not exist in the data store.

Enhance /GET anagrams by size endpoint
Fix endpoint naming convention to be `resource/:size` which is more conventional with REST standards. Also to clean up the JSON response, remove array within an array.

Removing spaces from words before they are inserted into Redis
Entering 'dear ' and 'read' create two separate keys in redis so they are not found as members of the same set.



## Example Endpoints

```{bash}
# Adding words to the corpus
$ curl -i -X POST -d '{ "words": ["read", "dear", "dare"] }' http://localhost:3000/words.json
HTTP/1.1 201 Created
...

# Fetching anagrams
$ curl -i http://localhost:3000/anagrams/read.json
HTTP/1.1 200 OK
...
{
  anagrams: [
    "dear",
    "dare"
  ]
}

# Specifying maximum number of anagrams
$ curl -i http://localhost:3000/anagrams/read.json?limit=1
HTTP/1.1 200 OK
...
{
  anagrams: [
    "dare"
  ]
}

# Delete single word
$ curl -i -X DELETE http://localhost:3000/words/read.json
HTTP/1.1 204 No Content
...

# Delete all words
$ curl -i -X DELETE http://localhost:3000/words.json
HTTP/1.1 204 No Content
...
```
