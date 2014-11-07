%w(rubygems sinatra digest/md5 rack-flash json restclient models haml).each  { |lib| require lib}

set :sessions, true
set :show_exceptions, false
use Rack::Flash


get '/' do
  if session[:userid].nil? then 
    @token = "http://#{env['HTTP_HOST']}/after_login"
    haml :login 
  else 
    redirect "/#{User.get(session[:userid]).nickname}"
  end
end

get '/logout' do
  session[:userid] = nil
  redirect '/'
end

# called by RPX after the login completes
post '/after_login' do
  profile = get_user_profile_with params[:token]
  user = User.find(profile['identifier'])
  if user.new_record?
    photo = profile ['email'] ? "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(profile['email'])}" : profile['photo'] 
    unless user.update_attributes({:nickname => profile['identifier'].hash.to_s(36), :email => profile['email'], :photo_url => photo, :provider => profile['provider']})
      flash[:error] = user.errors.values.join(',')
      redirect "/"
    end
    session[:userid] = user.id
    redirect '/change_profile'
  else
    session[:userid] = user.id
    redirect "/#{user.nickname}"    
  end
end

get '/profile' do
  load_users(session[:userid])
  haml :profile
end

get '/change_profile' do  haml :change_profile end

post '/save_profile' do
  user = User.get(session[:userid])
  unless user.update_attributes(:nickname => params[:nickname], :formatted_name => params[:formatted_name], :location => params[:location], :description => params[:description])
    flash[:error] = user.errors.values.join(',')
    redirect '/change_profile'
  end
  redirect "/#{user.nickname}"
end

get '/public_timeline' do
  @statuses = Status.all
  haml :public_timeline
end

post '/update' do
  user = User.get(session[:userid])
  Status.create(:text => params[:status], :user => user)
  redirect "/#{user.nickname}"
end

get '/followers' do
  load_users(session[:userid])
  @users = @myself.followers
  @message_count = message_count
  haml :followers
end

get '/follows' do
  load_users(session[:userid])
  @users = @myself.follows
  @message_count = message_count
  haml :follows
end

get '/replies' do
  load_users(session[:userid])
  @statuses = @myself.mentioned_statuses || []
  @message_count = message_count
  haml :replies
end

get '/tweets' do
  load_users(session[:userid])
  @status = @myself.statuses
  haml :user
end

get '/:nickname' do
  load_users(session[:userid])
  @user = @myself.nickname == params[:nickname] ? @myself : User.first(:nickname => params[:nickname])
  @message_count = message_count   
  if @myself == @user then 
    @statuses = @myself.displayed_statuses
    haml :home
  else 
    @statuses = @user.statuses
    haml :user
  end
end

get '/follow/:nickname' do
  Relationship.create(:user => User.first(:nickname => params[:nickname]), :follower => User.get(session[:userid]))
  redirect "/#{params[:nickname]}"
end

delete '/follow/:user_id/:follows_id' do
  Relationship.first(:follower_id => params[:user_id], :user_id => params[:follows_id]).destroy
  redirect "/"
end

get '/messages/:dir' do
  load_users(session[:userid])
  @friends = @myself.follows & @myself.followers
  case params[:dir]
  when 'received' then @messages = Status.all(:recipient_id => @myself.id); @label = "Direct messages sent only to you"
  when 'sent'     then @messages = Status.all(:user_id => @myself.id, :recipient_id.not => nil); @label = "Direct messages you've sent"
  end
  @message_count = message_count 
  haml :messages
end

post '/message/send' do
  recipient = User.first(:nickname => params[:recipient])
  Status.create(:text => params[:message], :user => User.get(session[:userid]), :recipient => recipient)
  redirect '/messages/sent'
end


error do
  @error = env['sinatra.error'].to_s
  haml :error
end

load 'helpers.rb'
load 'api.rb'