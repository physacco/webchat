Webchat::Application.routes.draw do
  get "chat/index"
  root :to => "chat#index"
end
