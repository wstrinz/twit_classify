require 'yaml'
require 'base64'
require 'octokit'

class GithubHelper
  class << self
    def gh_client(token)
      Octokit::Client.new(access_token: token)
    end

    def travis_hash(info_hash, user, repo)

      client = gh_client(info_hash["credentials"]["token"])
      client.auto_paginate = true

      begin
        travis_file = client.contents(user + "/" + repo, path: ".travis.yml")
      rescue Octokit::NotFound
        return false
      end

      YAML.load(Base64.decode64(travis_file.content))
    end

    def repos(info_hash)
      g = gh_client(info_hash["credentials"]["token"])
      user = g.user.login
      g.auto_paginate = true

      user_repos = g.repos(user)

      org_repos = g.org_repos('bendyworks')

      [
        user_repos.map{ |r|
          { name: r.name,
            owner: r.owner.login,
            url: "https://github.com/#{r.full_name}/" }
        }.sort_by{|r| r[:name].downcase},

        org_repos.map{|r|
          { name: r.name,
            owner: r.owner.login,
            url: "https://github.com/#{r.full_name}/" }
        }.sort_by{|r| r[:name].downcase},
      ].flatten
    end

    def add_deploy_key(info_hash, repo, title, key)
      gh_client(info_hash["credentials"]["token"]).add_deploy_key(repo, title, key)
    end
  end
end
