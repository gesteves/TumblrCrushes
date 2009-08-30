require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'csv'

def getUsernames(html)
  usernames = Array.new
  html.search("#posts > li").each do |li| # For every post
    # The post author's username is in div.post_info, but if there is more than one post in a row with the same author, only the first has .post_info
  	if li.search("div.post_info").any? # If the post has .post_info
  		usernames << li.search("div.post_info a").first.inner_html # I get the first link, which contains the username
  	else
  		usernames << usernames.last # If it doesn't have .post_info, it was written by the last author, so I just re-append the last item in the array
  	end
  end
  return usernames
end

def getLikes(url, count = 100)
  html = Hpricot(open(url))
  usernames = Array.new
  i = 0
  while usernames.length < count
    i += 1
    puts "Fetching page #{i} -- #{usernames.length} likes fetched" # Strangely, not all Tumblr like pages have 10 posts, for some reason.
    usernames.concat(getUsernames(html)) #Extracts the username from the current page's HTML and appends it to the array
    next_page = nil
    html.search('#pagination a').each {|a| next_page = "http://www.tumblr.com" + a.attributes['href'] if a.inner_html == "Next page &#8594;" } # Gets the URL of the next page, if any
    if next_page then html = Hpricot(open(next_page)) else break end # If there's a next page, I get it for the next iteration
  end
  usernames = usernames[0, count] # If for some reason I end up with more usernames than necessary, I get rid of the excess
  likes = Hash.new
  usernames.each {|u| if likes[u] == nil then likes[u] = 1 else likes[u] += 1 end } # I count each user's likes with a hash
  return likes
rescue OpenURI::HTTPError # Tumblr returns a 403 if the user doesn't exist or isn't sharing liked stuff
  puts "That user doesn't exist, or hasn't enabled the 'share posts I like' option"
end

def writeCSV(filename, likes)
  outfile = File.open(filename, 'wb')
    CSV::Writer.generate(outfile) do |csv|
      likes.each {|l| csv << l}
    end
    outfile.close
end

def calculateLikes
  print "Enter a Tumblr username: "
  username = gets[/\S+/]

  print "How far back do you want to go? (Default is 100, maximum is 1000) "
  count = gets.to_i
  if count == 0
    count = 100
  elsif count > 1000
  	count = 1000
  end
  puts "Getting stats for the last #{count} likes."
  likes = getLikes("http://www.tumblr.com/liked/by/" + username, count)
  likes = likes.to_a
  writeCSV("#{username}-#{count}.csv", likes.sort{|a,b| b[1]<=>a[1]}) # I turn the hash back into an array and sort it before passing it to the CSV writer
  puts "Done! File saved as #{username}-#{count}.csv"
rescue
  puts "Boom! Something bad happened. Try again"
end

calculateLikes

