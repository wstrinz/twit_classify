require 'rest-client'
require 'pry'
require 'sinatra'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-github'
require 'active_support'
require 'active_support/core_ext'
require 'stuff-classifier'
require 'redis'
require 'twitter'
require 'rack/ssl-enforcer'
require 'rack-flash'

require_relative 'github_helper'
require_relative 'tclassifier'
require_relative 'twit_helper'

helpers do
  def sample_oauth
    if File.exist? "dev_data/oauth_token"
      IO.read('dev_data/oauth_token').strip
    else
      ENV["OAUTH_TOKEN"]
    end
  end

  def sample_auth_hash
    { "credentials" => { "token"    => sample_oauth },
      "info"        => { "nickname" => "wstrinz"    } }
  end

  def authenticated?
    session[:authenticated]
  end

  def ensure_authenticated
    unless authenticated?
      authenticate!
    end
  end

  def authenticate!
    unless self.class.production?
      session[:authenticated] = true
      session[:auth_hash] = sample_auth_hash
    else
      redirect '/auth/github'
    end
  end

  def get_latest_unclassified_tweet(account)
    TwitHelper.new(account).get_tweets.find do |t|
      !$redis.hget(account, t['id'])
    end
  end

  def categories_for(account)
    TClassifier.new(account).category_list
  end

  def new_category?(account, classification)
    !TClassifier.new(account).categories.include?(classification.to_sym)
  end

  def get_accuracy_count
    hkey = params[:account]
    $redis.hget(hkey, 'accuracy')
  end

  def update_accuracy_count
    hkey = params[:account]
    if params[:guessed_class].present? && !new_category?(hkey, params[:classification])
      total = ($redis.hget(hkey, 'total') || 0).to_i
      correct = ($redis.hget(hkey, 'correct') || 0).to_i

      if params[:guessed_class] == params[:classification]
        correct += 1
      end

      total += 1

      accuracy = ((correct.to_f / total.to_f) * 100.0).round(2)
      correct = $redis.hmset(hkey, 'accuracy', accuracy, 'total', total, 'correct', correct)
    end
  end

  def num_classifications_for(account)
    TClassifier.new(account).number_of_classifications
  end

  def logout!
    session.clear
  end
end

configure do
  if development?
    $redis = Redis.new
    store = StuffClassifier::RedisStorage.new('classifications')
    session_secret = '123456789101112'
  else
    use Rack::SslEnforcer
    uri = URI.parse(ENV["REDISCLOUD_URL"])
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    store = StuffClassifier::RedisStorage.new('classifications', {host: uri.host, port: uri.port, password: uri.password})
    session_secret = ENV['SESSION_SECRET']
  end

  StuffClassifier::Base.storage = store

  use OmniAuth::Builder do
    user_scopes = 'user,read:org'
    provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: user_scopes
  end
  enable :sessions

  set :session_secret, session_secret

  use Rack::Flash
end

get '/' do
  redirect '/train'
end

get '/classify' do
  redirect '/classify/@bendyworks'
end

get '/classify/:account' do
  "classify page for #{params[:account]}"
end

get '/train' do
  redirect '/train/@bendyworks'
end

get '/train/:account' do
  if authenticated?
    @twitter_account = params[:account] || "@bendyworks"
    @user = session[:auth_hash]["info"]["nickname"]

    @tweet = get_latest_unclassified_tweet(@twitter_account)
    unless @tweet
      raise "No tweets for #{@twitter_account}. Should probably handle this better"
    end

    @current_classification = TClassifier.new(@twitter_account).classify(@tweet['text'])
    @n_classifications = num_classifications_for(@twitter_account)
    @categories = categories_for(@twitter_account) || {}
    @accuracy = get_accuracy_count

    haml :train
  else
    redirect '/login'
  end
end

post '/train/:account' do
  unless authenticated?
    redirect '/login'
  end

  param_map = {account: params[:account], text: params[:text],
               classification: params[:classification], id: params[:id]}
  acct, txt, klass, id = param_map.values

  if param_map.values.all?(&:present?)
    update_accuracy_count
    cls = TClassifier.new(acct)
    cls.train(klass, txt)
    $redis.hset(acct, id, true)
    flash[:notice] = "Success"
    redirect "/train/#{acct}"
  else
    flash[:notice] = "missing param(s): #{param_map.reject{|k, v| v.present?}.map(&:first)}"
    redirect "/train/#{acct}"
  end
end

get '/login' do
  if authenticated?
    redirect '/classify'
  else
    haml :login
  end
end

get '/logout' do
  logout!
  redirect '/'
end

get '/reauth' do
  authenticate!
  redirect '/'
end

get '/auth/:provider/callback' do
  content_type :json

  auth_hash = request.env['omniauth.auth']
  session[:authenticated] = true
  session[:auth_hash] = auth_hash
  redirect "/"
end
