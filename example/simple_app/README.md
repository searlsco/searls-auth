# A simple searls-auth app

This README walks you through setting up searls-auth in a fresh Rails app. It was generated on April 16, 2025, with Rails v8.0.2 and Ruby v3.4.2 using this command:

```
rails new simple_app --skip-docker --skip-keeps --skip-action-mailbox --skip-action-text --skip-active-storage --skip-action-cable --skip-jbuilder --skip-thruster --skip-rubocop --skip-brakeman --skip-ci --skip-kamal --skip-solid
```

Below I'll document each thing I did to integrate [searls-auth](/) into the app.

### 1. Install

Add the gem to the Gemfile, then run `bundle` to install it:

```
gem "searls-auth"
```

### 2. Configure searls-auth

Create an initializer for configuring searls-auth in `config/initializers/searls_auth.rb`:

```ruby
# config/initializers/searls_auth.rb
Rails.application.config.after_initialize do
  Searls::Auth.configure do |config|
    # You can find the defaults in searls_auth's Searls::Auth::DEFAULT_CONFIG in 'lib/searls/auth.rb'
    #
    # Override any option with its attr_writer like:
    # config.app_name = "POSSE Party"
  end
end
```

### 3. Mount the Searls::Auth::Engine

Mount the gem's [engine](https://guides.rubyonrails.org/engines.html) alongside your app's routes. In this case, we'll reserve the path prefix `/auth` for searls-auth:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # …
  mount Searls::Auth::Engine => "/auth"
  # root "posts#index"
end
```

### 4. Verify you see the login page

Once mounted, you should be able to visit [http://localhost:3000/auth/login](http://localhost:3000/auth/login) and see a very boring login form:

![Login screen](https://github.com/user-attachments/assets/12076267-27c0-41cc-90d1-2b4ff435126e)

### 5. Require authentication for appropriate actions

Of course, if you need an auth library, it's because there are parts of your app you don't want unauthenticated users to access. For illustration, I'll add a members-only page next.

Instead of entangling your application code, searls-auth only sets `session[:user_id]` when a user logs in; enforcing access restrictions based on this is up to you. A common way to do that is to add a method to your `ApplicationController` that redirects to a login page for use as a [before_action callback](https://guides.rubyonrails.org/action_controller_overview.html#before-action) on members-only routes.

First I added a `current_user` method to be able to easily reference the currently-logged-in user, then referenced it in `require_user`, which performs a redirect if no current user is set:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  def current_user
    return if session[:user_id].blank?

    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_user
    if current_user.blank?
      redirect_to searls_auth.login_url(
        redirect_path: request.original_fullpath,
        redirect_subdomain: request.subdomain
      ), allow_other_host: true
    end
  end
end
```

That's all we need to tell our controllers to only allow authenticated users:

```ruby
# app/controllers/only_members_controller.rb
class OnlyMembersController < ApplicationController
  before_action :require_user

  def show
  end
end
```

And a corresponding view:

```erb
<!-- app/views/only_members/show.html.erb -->
🤫 It's member time 🤐
```

And add a resource to our routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # …
  resource :only_members

  mount Searls::Auth::Engine => "/auth"
  # …
end
```

Now, if you visit [http://localhost:3000/only_members](http://localhost:3000/only_members) you should be redirected to the login page.

**[Bonus:** You might notice the query string `?redirect_path=%2Fonly_members` was also tacked on, and that's because searls-auth is designed to preserve a user's initially-intended path and subdomain, so that after they sign in they can get back to wherever they were _intending_ to go instead of being routed to some default account page.**]**

### 6. Create a User model

Since we're starting from a blank app, we need a `users` table and corresponding `User` model. By default, searls-auth makes several assumptions (each of which can be overridden by configuration):

* Your user model is named `User`
* A user's unique ID is stored in the `id` column and email address in the `email` column (override with `user_finder_by_id` and `user_finder_by_email`, respectively)
* Optionally, if the user's name is available anywhere, it's accessible via `User#name` (override with `user_name_method`)
* The `User` model calls [generates_token for](https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html#method-i-generates_token_for) to create a token named `email_auth` (override with `token_generator` and `user_finder_by_token`)

Let's fulfill those default assumptions in this example app. Next I ran `bin/rails g migration create_users` to generate this migration file:

```ruby
# db/migrate/20250416182737_create_users.rb
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email, null: false
      t.timestamps

      t.index :email, unique: true
    end
  end
end
```

Then ran the migration with `bin/rake db:migrate`.

Next, I created a `User` model in `app/models` like this:

```ruby
class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :email_auth, expires_in: 30.minutes
end
```

**[Aside:** You might notice the `normalizes` call there. That's a Rails 7.1 feature that can help "massage" data. Calling `email.strip.downcase` before or persisting or querying on `email` will prevent user input with extraneous whitespace or arbitrary upper/lower case variations from ruining your day.**]**

### 7. Add the letter_opener gem for a more pleasant dev experience

You _could_ try to scrutinize the emails sent by searls-auth in the console, but that's no way to live, so I like to pull in the [letter_opener](https://github.com/ryanb/letter_opener) gem:

```ruby
# Gemfile
group :development do
  #…
  gem "letter_opener"
end
```

And then enable it:

```ruby
# config/environments/development.rb
Rails.application.configure do
  #…
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
end
```

### 8. Register our first user

As you can see, almost all of the "coding" done so far in the app is basic housekeeping of responsibilities your app should own itself. (Unsolicited advice: if you _want_ a gem to do shit like setting `session[:user_id]` and `before_action` hooks for you, that is a bad thing to want and you will regret it later.)

So what does the searls-auth gem _actually do_? Well, let's restart our server with `bin/rails s` and find out:

1. Visit [http://localhost:3000/auth/login](http://localhost:3000/auth/login)
2. Type in `person@example.com` into the form
3. Realize it's a login form and then click "Sign up", which will route you to [http://localhost:3000/auth/register](http://localhost:3000/auth/register)
4. Notice you don't have to re-type the email address and appreciate Justin's commitment to little touches. [Remembering the user's email in sessionStorage](/app/javascript/controllers/searls_auth_login_controller.js) is another little bonus I threw in this gem because it's maddening to have to type in one's email twice
5. Click "Register" and you _should_ see a thoroughly-stylish purple e-mail pop up thanks to `letter_opener`
6. Click the "Login" link _or_ enter the six digit code in the email, up to you.
7. You'll be routed to the application root path, but you can configure where to send new users with the `redirect_path_after_register` configuration option

Here's what the searls-auth default email templates look like if you're not playing the home version of the game yourself:

![Fancy email](https://github.com/user-attachments/assets/849726d3-220b-4d8d-b420-3e77336f34dd)

And for non-HTML renderers:

![Text email](https://github.com/user-attachments/assets/984dd2a9-61dd-4c98-9992-c27dc7e0781f)

### 9. Try out the login flow

To test out login, you can first test logout by visiting [http://localhost:3000/auth/logout](http://localhost:3000/auth/logout), which should take you back to `http://localhost:3000/auth/login` and set a flash message.

From here, let's do this:

1. Visit [http://localhost:3000/only_members](http://localhost:3000/only_members)
2. See that we're redirected to [http://localhost:3000/auth/login?redirect_path=%2Fonly_members](http://localhost:3000/auth/login?redirect_path=%2Fonly_members)
3. Type in `person@example.com` and click
4. This time, however you authenticated login last time, _try the other one_. In my case, that means copy-pasting the numbers 964522 into my browser (hopefully your numbers are different, I'm not really into crypto)
5. With any luck, you'll see the members-only content. If not, one of us fucked up

### 10. Reset a forgotten password

With password login enabled, the default view now includes a "Forgot your password?" link. Clicking it lands on a lightweight form that just asks for an email address.

1. Visit [http://localhost:3000/auth/login](http://localhost:3000/auth/login) and click "Forgot your password?"
2. Submit `person@example.com`
3. Open the email that appears in `letter_opener`
4. Follow the "Reset password" button and choose a brand new password

If you leave the reset form open long enough, the link will expire (30 minutes by default). You can tune expiry, copy, templates, and auto-login behavior through the new configuration knobs documented in `Searls::Auth::DEFAULT_CONFIG`.

### 11. Carry on

From this point on, you should hopefully be able to think about something other than authentication for a while. Remember to check out [auth.rb's DEFAULT_CONFIG](/lib/searls/auth.rb) constant for some guidance on the customization options that searls-auth offers.
