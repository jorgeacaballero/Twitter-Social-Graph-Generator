# Twitter Social Graph Generator - TSGG
# National Tsing Hua University - Summer Course Lab
# Created by:
# 	Jorge Caballero
# 	Wilfredo Mejía
# 	Daniela Godoy
# 	Iris Ferrera

require 'twitter'
require 'active_record'
puts "Twitter Social Graph Generator - TSGG"

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'db/points.db' #comment this if you are going to debug
  #:database => ':memory:' #uncomment this if you are going to debug
)

class Point < ActiveRecord::Base
end

fetch_twitter = false # before changing this to true, delete the existing db to regenerate a new one
write_net = true
run_migration = false
primary_node = "Jorge_Caballero"

if run_migration
  ActiveRecord::Schema.define do
    create_table :points do |t|
      t.string :follower
      t.string :followee
    end
  end
end

def twitter_client
  Twitter::REST::Client.new do |config|
    config.consumer_key = "4kjOLbXmiG8jfUkT8tqGCp0lZ"
    config.consumer_secret = "wwUrSpnz0Fkzg0BJeagLuaSxmjUVO6fGUTGPnbRYXBiSWQNGYj"
    config.access_token = "331403187-P1Ue7SbdYYSKwGf0cBPkptrk5dcPBvS3qPRzMcpG"
    config.access_token_secret = "SlzpQEELV464NaesuA01m7JLMnQEYJU3O89lOlYwZHzaW"
  end
end
 
def fetch_all_friends(twitter_username, max_attempts = 100)
  num_attempts = 0
  client = twitter_client
  running_count = 0
  cursor = -1
  while (cursor != 0) do
    begin
      num_attempts += 1
      friends = client.friends(twitter_username, {:cursor => cursor, :count => 10} )
      friends.each do |f|
        running_count += 1
        puts "Adding Friend: \"#{running_count}\",\"#{f.name.gsub('"','\"')}\",\"#{f.screen_name}\""
        p = Point.create!(
        	follower: twitter_username,
        	followee: f.screen_name,
        	)
        if running_count == 10
        	sleep 2
        	return "Done 10"
        end
      end
      cursor = friends.next_cursor
      break if cursor == 0
    rescue Twitter::Error::TooManyRequests => error
      if num_attempts <= max_attempts
        cursor = friends.next_cursor if friends && friends.next_cursor
        puts "#{running_count} done from rescue block..."
        puts "Hit rate limit, sleeping for #{error.rate_limit.reset_in}..."
        sleep error.rate_limit.reset_in
        retry
      else
        raise
      end
    end
  end
end

def fetch_all_followers(twitter_username, max_attempts = 100)
  num_attempts = 0
  client = twitter_client
  running_count = 0
  cursor = -1
  while (cursor != 0) do
    begin
      num_attempts += 1
      friends = client.followers(twitter_username, {:cursor => cursor, :count => 10} )
      friends.each do |f|
        running_count += 1
        puts "Adding Follower: \"#{running_count}\",\"#{f.name.gsub('"','\"')}\",\"#{f.screen_name}\""
        p = Point.create!(
        	follower: f.screen_name,
        	followee: twitter_username,
        	)
        if running_count == 10
        	sleep 2
        	return "Done 10"
        end
      end
      cursor = friends.next_cursor
      break if cursor == 0
    rescue Twitter::Error::TooManyRequests => error
      if num_attempts <= max_attempts
        cursor = friends.next_cursor if friends && friends.next_cursor
        puts "#{running_count} done from rescue block..."
        puts "Hit rate limit, sleeping for #{error.rate_limit.reset_in}..."
        sleep error.rate_limit.reset_in
        retry
      else
        raise
      end
    end
  end
end

if fetch_twitter
	puts "Fetching, this may take a while..."
	puts fetch_all_friends(primary_node)
	puts fetch_all_followers(primary_node)

	points = Point.group(:follower).first(11)
	count = 1
	points.each{ |p|
		puts fetch_all_friends(p.follower)
		puts fetch_all_followers(p.follower)
		percent = (count.to_f/points.count)*100
		percent = percent.round(2)
		puts "#{count} out of #{points.count} processed this represents #{percent}%"
		count += 1
	}

	puts "Finished fetching, this is what we got:"
	final = Point.all
	final.each { |p|
		puts "#{p.follower} follows #{p.followee}"
	}

	
end

if write_net
	net = File.new("final.net", "w")

	final = Point.uniq.pluck(:follower)
  final_followees = Point.uniq.pluck(:followee)
  final_followees.each { |p|
    unless final.include? p
      final.push(p)
    end
  }

	count = 1
  indices = Hash.new
	net.puts "*Vertices #{final.count}"
	final.each { |p|
		net.puts "#{count} \"#{p}\" 0.0 0.0 0.0"
    indices.store(count, p) 
		count += 1
	}
	net.puts "*Arcs"

  puts indices

  Point.all.each { |p|
    follower = indices.select{|key, hash| hash == p.follower}
    followee = indices.select{|key, hash| hash == p.followee}
    net.puts "#{follower.keys.join} #{followee.keys.join} 1.0"
  }

	#myfile.puts "\"#{running_count}\",\"#{f.name.gsub('"','\"')}\",\"#{f.screen_name}\""
end


