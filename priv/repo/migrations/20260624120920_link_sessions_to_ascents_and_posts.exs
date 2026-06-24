defmodule Ascents.Repo.Migrations.LinkSessionsToAscentsAndPosts do
  use Ecto.Migration

  def up do
    alter table(:ascents) do
      add :session_id, references(:sessions, on_delete: :delete_all)
      add :post_type, :string, null: false, default: "ascent"
    end

    drop unique_index(:ascents, [:post_id])

    create unique_index(:ascents, [:post_id],
             where: "session_id IS NULL",
             name: :ascents_post_id_index
           )

    create index(:ascents, [:session_id])
    create index(:ascents, [:user_id, :session_id])

    create unique_index(:posts, [:id, :user_id, :gym_id, :post_type], name: :posts_integrity_key)

    create unique_index(:boulder_problems, [:id, :gym_id], name: :boulder_problems_integrity_key)

    drop constraint(:posts, :posts_post_type_check)

    create constraint(:posts, :posts_post_type_check,
             check: "post_type IN ('normal', 'ascent', 'session')"
           )

    create constraint(:ascents, :ascents_post_type_check,
             check:
               "(session_id IS NULL AND post_type = 'ascent') OR " <>
                 "(session_id IS NOT NULL AND post_type = 'session')"
           )

    execute("""
    ALTER TABLE sessions
    ADD CONSTRAINT sessions_post_integrity_fkey
    FOREIGN KEY (post_id, user_id, gym_id, post_type)
    REFERENCES posts (id, user_id, gym_id, post_type)
    ON DELETE CASCADE
    """)

    execute("""
    ALTER TABLE ascents
    ADD CONSTRAINT ascents_post_integrity_fkey
    FOREIGN KEY (post_id, user_id, gym_id, post_type)
    REFERENCES posts (id, user_id, gym_id, post_type)
    ON DELETE CASCADE
    """)

    execute("""
    ALTER TABLE ascents
    ADD CONSTRAINT ascents_route_gym_integrity_fkey
    FOREIGN KEY (boulder_problem_id, gym_id)
    REFERENCES boulder_problems (id, gym_id)
    ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE ascents
    ADD CONSTRAINT ascents_session_integrity_fkey
    FOREIGN KEY (session_id, user_id, gym_id, post_id, post_type)
    REFERENCES sessions (id, user_id, gym_id, post_id, post_type)
    ON DELETE CASCADE
    """)

    execute("""
    CREATE FUNCTION enforce_session_graph_integrity()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
      target_session_id bigint;
      target_post_id bigint;
    BEGIN
      IF TG_TABLE_NAME = 'sessions' THEN
        target_session_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
        target_post_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.post_id ELSE NEW.post_id END;
      ELSIF TG_TABLE_NAME = 'posts' THEN
        target_post_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
      ELSE
        target_session_id :=
          CASE WHEN TG_OP = 'DELETE' THEN OLD.session_id ELSE NEW.session_id END;
        target_post_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.post_id ELSE NEW.post_id END;
      END IF;

      IF target_session_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM sessions AS session
        JOIN posts AS post ON post.id = session.post_id
        WHERE session.id = target_session_id
          AND (
            post.body IS DISTINCT FROM session.notes OR
            post.image_object_key IS DISTINCT FROM session.image_object_key OR
            post.visibility IS DISTINCT FROM session.visibility OR
            post.deleted_at IS DISTINCT FROM session.deleted_at
          )
      ) THEN
        RAISE EXCEPTION 'session and post mirrored fields must match'
          USING ERRCODE = '23514', CONSTRAINT = 'sessions_post_mirrors_check';
      END IF;

      IF target_session_id IS NOT NULL
         AND EXISTS (SELECT 1 FROM sessions WHERE id = target_session_id)
         AND NOT EXISTS (SELECT 1 FROM ascents WHERE session_id = target_session_id) THEN
        RAISE EXCEPTION 'a session must contain at least one ascent'
          USING ERRCODE = '23514', CONSTRAINT = 'sessions_require_ascent_check';
      END IF;

      IF target_session_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM sessions AS session
        JOIN ascents AS ascent ON ascent.session_id = session.id
        WHERE session.id = target_session_id
          AND (
            ascent.climbed_at IS DISTINCT FROM session.started_at OR
            ascent.deleted_at IS DISTINCT FROM session.deleted_at
          )
      ) THEN
        RAISE EXCEPTION 'session ascent mirrored fields must match'
          USING ERRCODE = '23514', CONSTRAINT = 'session_ascents_mirrors_check';
      END IF;

      IF target_post_id IS NOT NULL
         AND EXISTS (
           SELECT 1 FROM posts WHERE id = target_post_id AND post_type = 'session'
         )
         AND (SELECT count(*) FROM sessions WHERE post_id = target_post_id) <> 1 THEN
        RAISE EXCEPTION 'a session post must own exactly one session'
          USING ERRCODE = '23514', CONSTRAINT = 'session_posts_require_session_check';
      END IF;

      IF TG_OP = 'DELETE' THEN
        RETURN OLD;
      ELSE
        RETURN NEW;
      END IF;
    END;
    $$
    """)

    for table <- ~w(posts sessions ascents) do
      execute("""
      CREATE CONSTRAINT TRIGGER #{table}_session_graph_integrity
      AFTER INSERT OR UPDATE OR DELETE ON #{table}
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW
      EXECUTE FUNCTION enforce_session_graph_integrity()
      """)
    end
  end

  def down do
    for table <- ~w(ascents sessions posts) do
      execute("DROP TRIGGER #{table}_session_graph_integrity ON #{table}")
    end

    execute("DROP FUNCTION enforce_session_graph_integrity()")

    execute("ALTER TABLE ascents DROP CONSTRAINT ascents_session_integrity_fkey")
    execute("ALTER TABLE ascents DROP CONSTRAINT ascents_route_gym_integrity_fkey")
    execute("ALTER TABLE ascents DROP CONSTRAINT ascents_post_integrity_fkey")
    execute("ALTER TABLE sessions DROP CONSTRAINT sessions_post_integrity_fkey")

    # A rollback to the pre-session schema cannot represent grouped ascents or
    # session posts. Remove only rows created by this feature before restoring
    # the old one-ascent-per-post and post-type constraints.
    execute("DELETE FROM ascents WHERE session_id IS NOT NULL")
    execute("DELETE FROM sessions")
    execute("DELETE FROM posts WHERE post_type = 'session'")

    drop constraint(:ascents, :ascents_post_type_check)

    drop constraint(:posts, :posts_post_type_check)

    create constraint(:posts, :posts_post_type_check, check: "post_type IN ('normal', 'ascent')")

    drop unique_index(:boulder_problems, [:id, :gym_id], name: :boulder_problems_integrity_key)

    drop unique_index(:posts, [:id, :user_id, :gym_id, :post_type], name: :posts_integrity_key)

    drop index(:ascents, [:user_id, :session_id])
    drop index(:ascents, [:session_id])
    drop unique_index(:ascents, [:post_id], name: :ascents_post_id_index)

    create unique_index(:ascents, [:post_id])

    alter table(:ascents) do
      remove :session_id
      remove :post_type
    end
  end
end
