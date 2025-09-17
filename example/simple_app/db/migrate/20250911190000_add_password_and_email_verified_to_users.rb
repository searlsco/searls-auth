class AddPasswordAndEmailVerifiedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_digest, :string
    add_column :users, :email_verified_at, :datetime
  end
end
