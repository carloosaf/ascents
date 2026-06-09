defmodule Ascents.Repo.Migrations.AddImageObjectKeyToGyms do
  use Ecto.Migration

  def change do
    alter table(:gyms) do
      add :image_object_key, :string
    end
  end
end
