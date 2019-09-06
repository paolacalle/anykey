Rails.application.routes.draw do
    
  devise_for :users, controllers: { invitations: "users/invitations" },
             path_names:  { sign_in: "login", sign_out: "logout" }
                       
  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
  
    authenticated :user do
      root to: "home#index", as: :authenticated_user_root
    end
  
    unauthenticated do
      root to: "home#index"
    end
  
    resources :pledges,        only: [ :index, :create, :show ], path: :pledge
    resources :affiliates,     only: [ :index, :new, :create, :edit, :update ]
    resources :resources,      only: [ :index ]
    resources :stories,        only: [ :index, :new, :create, :edit, :update ]
    resources :reports,        only: [ :index, :show, :new, :create ] do
      member do
        post :dismiss
        post :undismiss        
      end
      resources :warnings,     only: [ :new, :create ]
      resources :revocations,  only: [ :new, :create ]
    end
                                                   
    resources :staff,          only: [ :index ]                              
    resources :users,          only: [ :edit, :update ]
    post '/users/:id/remove_avatar', to: 'users#remove_avatar',         as: :remove_avatar
    
  end
    
end
