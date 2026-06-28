defmodule Ascents.Repo.Migrations.DropSessionTitle do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE sessions DROP COLUMN IF EXISTS title")
  end

  def down do
    alter table(:sessions) do
      add :title, :string
    end
  end
end
