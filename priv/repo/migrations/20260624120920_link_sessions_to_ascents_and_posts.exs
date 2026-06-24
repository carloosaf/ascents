defmodule Ascents.Repo.Migrations.LinkSessionsToAscentsAndPosts do
  use Ecto.Migration

  def up do
    alter table(:ascents) do
      add :session_id, references(:sessions, on_delete: :delete_all)
    end

    drop unique_index(:ascents, [:post_id])

    create unique_index(:ascents, [:post_id],
             where: "session_id IS NULL",
             name: :ascents_post_id_index
           )

    create index(:ascents, [:session_id])
    create index(:ascents, [:user_id, :session_id])

    drop constraint(:posts, :posts_post_type_check)

    create constraint(:posts, :posts_post_type_check,
             check: "post_type IN ('normal', 'ascent', 'session')"
           )
  end

  def down do
    drop constraint(:posts, :posts_post_type_check)

    create constraint(:posts, :posts_post_type_check, check: "post_type IN ('normal', 'ascent')")

    drop index(:ascents, [:user_id, :session_id])
    drop index(:ascents, [:session_id])
    drop unique_index(:ascents, [:post_id], name: :ascents_post_id_index)

    create unique_index(:ascents, [:post_id])

    alter table(:ascents) do
      remove :session_id
    end
  end
end
