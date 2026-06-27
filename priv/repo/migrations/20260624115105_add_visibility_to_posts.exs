defmodule Ascents.Repo.Migrations.AddVisibilityToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :visibility, :string, null: false, default: "public"
    end

    create index(:posts, [:gym_id, :visibility])
    create index(:posts, [:user_id, :visibility])

    create constraint(:posts, :posts_visibility_check,
             check:
               "visibility IN ('public', 'friends') OR (post_type = 'ascent' AND visibility = 'private')"
           )
  end
end
