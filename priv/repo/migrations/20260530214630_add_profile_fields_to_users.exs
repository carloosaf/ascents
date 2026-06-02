defmodule Ascents.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :citext
      add :display_name, :string
      add :bio, :string
      add :avatar_object_key, :string
    end

    execute "UPDATE users SET username = 'user_' || id WHERE username IS NULL", ""

    alter table(:users) do
      modify :username, :citext, null: false
    end

    create unique_index(:users, [:username])
  end
end
