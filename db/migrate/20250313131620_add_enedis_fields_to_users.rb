class AddEnedisFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :usage_point_id, :string
    add_column :users, :enedis_auth_code, :string
    add_column :users, :enedis_token, :string
    add_column :users, :enedis_token_expires_at, :datetime
    add_column :users, :enedis_refresh_token, :string
  end
end
