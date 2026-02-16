defmodule Horus.Repo.Migrations.CreateInitialSchema do
  use Ecto.Migration

  def change do
    # Tenants table - multi-tenancy support
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :status, :string, null: false, default: "active"
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    create unique_index(:tenants, [:slug])
    create index(:tenants, [:status])

    # Users table - user accounts with roles
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :hashed_api_key, :string
      add :role, :string, null: false, default: "user"
      add :status, :string, null: false, default: "active"
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    create unique_index(:users, [:email])
    create index(:users, [:role])
    create index(:users, [:status])

    # User-tenant assignments - many-to-many relationship
    create table(:user_tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
      add :status, :string, null: false, default: "active"

      timestamps()
    end

    create unique_index(:user_tenants, [:user_id, :tenant_id])
    create index(:user_tenants, [:tenant_id])
    create index(:user_tenants, [:user_id])

    # Blueprints table - global validation templates
    create table(:blueprints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :dsl, :text, null: false
      add :compiled_ast, :jsonb
      add :parameters, :jsonb, default: "[]"
      add :status, :string, null: false, default: "draft"
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    create unique_index(:blueprints, [:name])
    create index(:blueprints, [:status])
    create index(:blueprints, [:created_by_id])

    # Rules table - instantiated blueprints per tenant
    create table(:rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :blueprint_id, references(:blueprints, type: :binary_id, on_delete: :restrict),
        null: false

      add :name, :string, null: false
      add :description, :text
      add :bound_ast, :jsonb, null: false
      add :parameters, :jsonb, default: "{}"
      add :status, :string, null: false, default: "active"
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    create index(:rules, [:tenant_id])
    create index(:rules, [:blueprint_id])
    create index(:rules, [:status])
    create index(:rules, [:tenant_id, :status])
    create unique_index(:rules, [:tenant_id, :name])
  end
end
