get '/api/statuses/user_timeline' do
  protected!
  email = *@auth.credentials
  user = User.first(:email => email)
  user.displayed_statuses.to_json if user
end

get '/api/statuses/public_timeline' do
  protected!
  Status.all.to_json
end

post '/api/statuses/update' do
  protected!
  email = *@auth.credentials
  user = User.first(:email => email)
  if user
    status = Status.new(:text => params[:text], :user => user)
    throw(:halt, [401, "Not authorized\n"]) unless status.save
  end
end
