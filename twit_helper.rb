class TwitHelper
  CONFIG = {
    consumer_key: ENV['TC_CONSUMER_KEY'],
    consumer_secret: ENV['TC_CONSUMER_SECRET'],
    access_token: ENV['TC_ACCESS_TOKEN'],
    access_token_secret: ENV['TC_ACCESS_SECRET']
  }

  EXPIRATION_TIME = 1.hour

  def initialize(account)
    @account = account
    @account_sub = account.gsub('@', '')
    @client = Twitter::REST::Client.new(CONFIG)
  end

  def client
    @client
  end

  def get_tweets
    if cached_tweets.present?
      JSON.parse(cached_tweets)
    else
      tweets = client.user_timeline(@account_sub, count: 200)
      $redis.set("#{@account}_cache", tweets.to_json)
      $redis.expire(@account, EXPIRATION_TIME)
      tweets.as_json
    end
  end

  def cached_tweets
    $redis.get("#{@account}_cache")
  end
end
