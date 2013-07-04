# generation2
# by Andrey Viktorov
# http://tehead.ru
require 'sinatra'
require 'json'
require 'digest/md5'
require 'sequel'
require './inc'

# Change it!
set :port, 80
set :bind, '192.168.0.100'
# Password for registration
registerpassword = "passWd123"

DB = Sequel.connect('mysql2://root:password@localhost/generation2')
class User < Sequel::Model(:users)
end

class Profile < Sequel::Model(:profiles)
end

class Token < Sequel::Model(:tokens)
end

class JoinData < Sequel::Model(:joindata)
end

def invalidate_token(clientid, token)
  Token.where(:clientid => clientid, :token => token).delete
  JoinData.where(:token => token).delete
end

def invalidate_tokens(userhash)
  Token.where(:userhash => userhash).delete
  JoinData.where(:userhash => userhash).delete
end

def generate_token(username)
  return Digest::MD5.hexdigest(Digest::MD5.hexdigest(username) + Random.rand(100000...900000).to_s())
end

def passhash(password)
  return Digest::MD5.hexdigest(Digest::MD5.hexdigest(password))
end

def parse_params(params)
  return Rack::Utils.parse_query params
end

post '/authenticate' do
  data = request.body.read
  if data.is_json?
    json = JSON.parse(data)
    responce = Hash.new
    if json['username'].present? && json['password'].present? && json['clientToken'].present?
      users = User.where(:mail => json['username'], :password => passhash(json["password"])).first
      if users
        invalidate_tokens(users.hashid)
        token = Token.new
        tokengen = generate_token(json['username'])
        token.token = tokengen
        token.userhash = users.hashid
        token.clientid = json["clientToken"]
        token.save
        responce["accessToken"] = tokengen
        responce["clientToken"] = json["clientToken"]
        profile = Profile.where(:userid => users.hashid).first
        responce["availableProfiles"] = Array.new(1) { Hash.new }
        responce["availableProfiles"][0]["id"] = profile.hashid
        responce["availableProfiles"][0]["name"] = profile.username
        responce["selectedProfile"] = Hash.new
        responce["selectedProfile"]["id"] = profile.hashid
        responce["selectedProfile"]["name"] = profile.username
        puts responce.to_json
      responce.to_json
      else
        profile = Profile.where(:username => json['username']).first
        users = User.where(:hashid => profile.userid, :password => passhash(json["password"])).first
        if users
          invalidate_tokens(users.hashid)
          token = Token.new
          tokengen = generate_token(json['username'])
          token.token = tokengen
          token.userhash = users.hashid
          token.clientid = json["clientToken"]
          token.save
          responce["accessToken"] = tokengen
          responce["clientToken"] = json["clientToken"]
          profile = Profile.where(:userid => users.hashid).first
          responce["availableProfiles"] = Array.new(1) { Hash.new }
          responce["availableProfiles"][0]["id"] = profile.hashid
          responce["availableProfiles"][0]["name"] = profile.username
          responce["selectedProfile"] = Hash.new
          responce["selectedProfile"]["id"] = profile.hashid
          responce["selectedProfile"]["name"] = profile.username
          puts responce.to_json
        responce.to_json
        else
          status 403
          responce["errorMessage"] = "Invalid credentials. Invalid username or password."
          responce["error"] = "ForbiddenOperationException"
        responce.to_json
        end
      end
    else
      status 403
      responce["errorMessage"] = "Invalid credentials. Invalid username or password."
      responce["error"] = "ForbiddenOperationException"
    responce.to_json
    end
  end
end

post '/invalidate' do
  data = request.body.read
  if data.is_json?
    json = JSON.parse(data)
    if json["clientToken"].present? && json["accessToken"].present?
      json = JSON.parse(data)
      invalidate_token(json["clientToken"], json["accessToken"])
    end
  end
end

post '/refresh' do
  data = request.body.read
  if data.is_json?
    json = JSON.parse(data)
    responce = Hash.new
    if json["clientToken"].present? && json["accessToken"].present?
      old_token = Token.where(:token => json["accessToken"], :clientid => json["clientToken"]).first
      if old_token
        profile = Profile.where(:userid => old_token.userhash).first
        invalidate_token(json["clientToken"], json["accessToken"])
        token = Token.new
        tokengen = generate_token(json["accessToken"])
        token.token = tokengen
        token.userhash = old_token.userhash
        token.clientid = json["clientToken"]
        token.save
        responce["accessToken"] = tokengen
        responce["clientToken"] = json["clientToken"]
        responce["selectedProfile"] = Hash.new
        responce["selectedProfile"]["id"] = profile.hashid
        responce["selectedProfile"]["name"] = profile.username
      responce.to_json
      else
        status 403
        responce["errorMessage"] = "Invalid token."
        responce["error"] = "ForbiddenOperationException"
      responce.to_json
      end
    end
  end
end

post '/validate' do
  puts request.body.read
end

post '/signout' do
  puts request.body.read
end

get '/session/joinserver' do
  got = parse_params(request.query_string)
  join = JoinData.new
  join.serverid = got["serverId"]
  session = got["sessionId"].split(":")
  JoinData.where(:userhash => session[2]).delete
  join.token = session[1]
  join.userhash = session[2]
  join.username = got["user"]
  token_exists = Token.where(:token => session[1], :userhash => session[2])
  if token_exists
    join.save
    "OK"
  else
    "Bad login"
  end
end

get '/session/checkserver' do
  got = parse_params(request.query_string)
  join = JoinData.where(:serverid => got["serverId"], :username => got["user"])
  if join
    "YES"
  else
    "NO"
  end
end

get '/register/:mail/:name/:password/:registerpassword' do
  if params[:registerpassword] == registerpassword
    user = User.new
    user.mail = params[:mail]
    hash = generate_token(params[:mail])
    user.hashid = hash
    user.password = passhash(params[:password])
    user.save
    profile = Profile.new
    profile.username = params[:name]
    profile.userid = hash
    profile.hashid = generate_token(params[:name])
    profile.save
    "Done"
  end
end

not_found do
  puts "Unknown request"
  "<a href='http://github.com/tehead/generation2'>Powered by generation2</a>"
end