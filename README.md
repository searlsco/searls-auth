# searls-auth

This gem provides a Ruby on Rails engine that implements a minimal, opinionated, and pleasant email-based authentication system. It has zero other dependencies, which is the correct number of dependencies.

For a detailed walk-through with pictures and whatnot, check out this [example app README](/example/simple_app/README.md). Below you'll find the basic steps for getting started.

## Install it

Add it to your Gemfile and `bundle` it:

```ruby
gem "searls-auth"
```

## Mount it

Next, you need to mount the gem's Engine to host any of the authentication controllers and mailers.

You can mount the engine at whatever you path you like (mounting it to "/" can result in some goofy behavior, so maybe not that one). I just do "/auth" because I'm boring:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # …
  mount Searls::Auth::Engine => "/auth"
  # …
end
```

If you run your development server and visit [http://localhost:3000/auth/login](http://localhost:3000/auth/login), you should see an ugly login page. (If things look really goofy, it's because the gem defaults to your app's `"application"` layout).

## Secure it

If you've got a `User` model with an `email` attribute, you're two-thirds of the way to this thing working. All you need now is to associate [a secure token](https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html#method-i-generates_token_for) with the model named `:email_auth`.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # …
  generates_token_for :email_auth, expires_in: 30.minutes
  # …
end
```

(You can [name all these things whatever you want](#configure-it), but this is what searls-auth will assume by default.)

I'm writing this README as I add searls-auth to my new [POSSE Party](https://posseparty.com) app. As soon as I added the above line I visited [http://localhost:3000/auth/login](http://localhost:3000/auth/login), typed in my email, hit "Log in", and saw this email get sent (thanks to [letter_opener](https://github.com/ryanb/letter_opener)):

![A default searls-auth login email](https://github.com/user-attachments/assets/07114dae-a95b-49bd-ba57-92042c62c1b7)

When I pasted in the six-digit code into the (also ugly) default verification page, it auto-submitted the form. That's because my has a vanilla [import maps](https://guides.rubyonrails.org/working_with_javascript_in_rails.html#import-maps) configuration, the least-bad of the various JavaScript ordeals Rails has on offer. (Don't use import maps? Then I leave figuring out how to load the gem's [Stimulus controllers](app/javascript/controllers/searls_auth_login_controller.js) as an exercise to the reader.)

I repeated the process to ensure the "magic link" also would have worked by visiting [http://localhost:3000/auth/logout](http://localhost:3000/auth/logout) and then clicking the link.

## Configure it

Almost every user-facing thing searls-auth does is configurable, because authentication is an _intimate and precious_ thing that every application must find a way to tweak, brand, and confuse.

To configure things, create an initializer:

```
touch config/initializers/searls_auth.rb
```

And paste this into it as a starting point:

```ruby
Rails.application.config.after_initialize do
  Searls::Auth.configure do |config|
    # You can find the defaults here-ish:
    # https://github.com/searlsco/searls-auth/blob/main/lib/searls/auth.rb#L14
    #
    # The expected type of each option is documented inline here-ish:
    # https://github.com/searlsco/searls-auth/blob/main/lib/searls/auth/config.rb#L3
    #
    # (Note that many options can take a proc or a value, which you may want)
    #
    # Override any option like this:
    # config.app_name = "POSSE Party"
  end
end
```
As stated in the comment above, you can find each configuration and its default value in the code.

## Use it

Of course, having a user be "logged in" or not doesn't mean anything if your application doesn't do anything with the knowledge. Users that are logged in will have `session[:user_id]` set to the value of the logged-in user's ID. Logged out users won't have anything set to `session[:user_id]`. What you do with that is your job, not this gem. (Wait, after 20 years does this mean I finally understand the difference between authentication and authorization? Better late than never.)

If this is your first rodeo and you just read the previous paragraph and thought, _yeah, but now what?_, check out the tail end of the [example app README](/example/simple_app/README.md#5-require-authentication-for-appropriate-actions), which shows an approach that a lot of apps use.
