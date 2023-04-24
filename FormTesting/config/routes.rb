Rails.application.routes.draw do
	root "search#search"
	get 'search', to: 'search#search'
	post 'search', to: 'search#search'
	post 'screenshot', to: 'search#getscreenshots' 
end
