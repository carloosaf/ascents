defmodule Ascents.Repo.Migrations.CreateFeedPostsAndComments do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :body, :text, null: false
      add :image_object_key, :string
      add :deleted_at, :utc_datetime
      add :gym_id, references(:gyms, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:gym_id, :inserted_at])
    create index(:posts, [:user_id])
    create index(:posts, [:deleted_at])

    create table(:comments) do
      add :body, :text, null: false
      add :deleted_at, :utc_datetime
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:post_id, :inserted_at])
    create index(:comments, [:user_id])
    create index(:comments, [:deleted_at])
  end
end
