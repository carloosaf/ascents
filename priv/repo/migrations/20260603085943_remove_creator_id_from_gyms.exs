defmodule Ascents.Repo.Migrations.RemoveCreatorIdFromGyms do
  use Ecto.Migration

  def up do
    drop_if_exists index(:gyms, [:creator_id])

    alter table(:gyms) do
      remove :creator_id
    end
  end

  def down do
    alter table(:gyms) do
      add :creator_id, references(:users, on_delete: :restrict)
    end

    create index(:gyms, [:creator_id])
  end
end
