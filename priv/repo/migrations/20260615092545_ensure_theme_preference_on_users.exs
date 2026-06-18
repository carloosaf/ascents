defmodule Ascents.Repo.Migrations.EnsureThemePreferenceOnUsers do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS theme_preference varchar(255) NOT NULL DEFAULT 'dark'
    """

    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'users_theme_preference_check'
      ) THEN
        ALTER TABLE users
        ADD CONSTRAINT users_theme_preference_check
        CHECK (theme_preference in ('system', 'light', 'dark'));
      END IF;
    END
    $$;
    """
  end

  def down, do: :ok
end
