ENV['RACK_ENV'] = 'test'

require_relative '../server.rb'
require 'rspec'
require 'rack/test'

include Rack::Test::Methods

def app
  Sinatra::Application
end

# def create_test_job(options = {})
#   default_config = {  job_name:             "test_job",
#                       github_repo:          "bendyworks/bw_poopdeck",
#                       build_script:         "bundle\nbundle exec rake",
#                       enable_pullrequests:  true }

#   config = default_config.merge(options)

#   JenkinsHelper.client.job.delete(config[:job_name]) rescue nil
#   JenkinsHelper.create_job(config)
# end

# def destroy_test_job(job_name = "test_job")
#   JenkinsHelper.client.job.delete(job_name) rescue nil
# end

# require 'vcr'

# VCR.configure do |c|
#   c.cassette_library_dir = 'spec/cassettes'
#   c.default_cassette_options = { :record => :new_episodes }
#   c.hook_into :webmock
#   c.configure_rspec_metadata!
#   c.allow_http_connections_when_no_cassette = true
# end

# RSpec.configure do |c|
#   c.treat_symbols_as_metadata_keys_with_true_values = true
# end
