require 'rest-client'
require 'sinatra'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-github'
require 'rack/ssl-enforcer'

require_relative 'github_helper.rb'

helpers do
  def sample_repos
    JSON.parse(IO.read('dev_data/repos.json'))
  end

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

  def logout!
    session.clear
  end
end

configure do
  if production?
    use Rack::SslEnforcer
  end
  use OmniAuth::Builder do
    user_scopes = 'user,repo,read:repo_hook,write:repo_hook,admin:repo_hook,read:org'
    provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: user_scopes
  end
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
end

get '/' do
  if authenticated?
    @twitter_account = params[:account] || "@bendyworks"
    @user = session[:auth_hash]["info"]["nickname"]
    haml :classify
  else
    haml :login
  end
end

get '/classify' do
  redirect '/'
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

get '/repositories' do
  ensure_authenticated
  content_type :json
  repos(session[:auth_hash]).to_json
end

get '/enabled_repositories' do
  ensure_authenticated
  content_type :json
  jenkins_repos.to_json
end

get '/test_config/:user/:repo' do
  ensure_authenticated
  content_type :json
  test_config(session[:auth_hash], params[:user], params[:repo]).to_json
end

get '/job_config/:job' do
  ensure_authenticated
  content_type :json
  job_config(params[:job]).to_json
end

get '/build_status/:job' do
  ensure_authenticated
  content_type :json
  build_status(params[:job]).to_json
end

get '/jenkins_url' do
  ensure_authenticated
  content_type :json
  {url: ENV["JENKINS_URL"]}.to_json
end

post '/enable_job' do
  ensure_authenticated
  content_type :json
  #begin
    enable_job(params[:data])
    {status: :success}.to_json
  #rescue Exception => e
   # {status: :failure, reason: e}.to_json
  #end
end

post '/delete_job/:job' do
  ensure_authenticated
  content_type :json
  begin
    delete_job(params[:job])
    {status: :success}.to_json
  rescue Exception => e
    {status: :failure, reason: e}.to_json
  end
end

post '/build_job/:job' do
  ensure_authenticated
  content_type :json
  build_job(params[:job])
  {status: :success}
end

post '/disable_job/:job' do
  ensure_authenticated
  content_type :json
  disable_job(params[:job])
end
