webchat
=======

Web-based XMPP/Jabber client. Built on [Candy](http://candy-chat.github.io/candy/).

## Getting started

1. clone this project
2. run `bundle check` (and `bundle install` if some gems are missing)
3. run `rails server` to start web server
4. start **nginx** with config files in *config/nginx*
5. start **ejabberd** with config files in *config/ejabberd*, register an account *foo@localhost* with password *123456*
6. Visit *http://127.0.0.1/* with your web browser.

## Steps to create this project

1. `cd /tmp`
2. `rails new webchat --skip-bundle --skip-active-record --skip-sprockets --skip-javascript`
3. `cd webchat`
4. `rm public/index.html`
5. `rails generate controller chat index`
6. edit *config/routes.rb*: add `root :to => "chat#index"`
7. edit *app/controllers/chat_controller.rb*
8. edit *app/views/layouts/application.html.erb*
9. edit *app/views/chat/index.html.erb*
10. edit *public/stylesheets/webchat.css*
11. put *public/javascripts/jquery-1.7.1.min.js*
12. edit *public/javascripts/libchat.js*
13. edit *public/javascripts/chatapp.js*
14. put Candy resource files to *public/candy*
