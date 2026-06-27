defmodule Ascents.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :title, :string, null: false
      add :notes, :text
      add :started_at, :utc_datetime, null: false
      add :image_object_key, :string
      add :visibility, :string, null: false, default: "public"
      add :post_type, :string, null: false, default: "session"
      add :deleted_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sessions, [:post_id])

    create unique_index(:sessions, [:id, :user_id, :gym_id, :post_id, :post_type],
             name: :sessions_integrity_key
           )

    create index(:sessions, [:user_id, :started_at])
    create index(:sessions, [:gym_id, :started_at])
    create index(:sessions, [:deleted_at])

    create constraint(:sessions, :sessions_post_type_check, check: "post_type = 'session'")

    create constraint(:sessions, :sessions_visibility_check,
             check: "visibility IN ('public', 'friends')"
           )
  end
end
