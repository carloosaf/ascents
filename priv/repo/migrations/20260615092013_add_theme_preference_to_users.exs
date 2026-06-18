defmodule Ascents.Repo.Migrations.AddThemePreferenceToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :theme_preference, :string, null: false, default: "dark"
    end

    create constraint(:users, :users_theme_preference_check,
             check: "theme_preference in ('system', 'light', 'dark')"
           )
  end
end
