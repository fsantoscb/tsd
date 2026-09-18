create table public."maintenance_asset_categories" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_asset_categories_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "maintenance_asset_categories_organization_id_name_key" UNIQUE (organization_id, name),
  constraint "maintenance_asset_categories_pkey" PRIMARY KEY (id)
);
alter table public."maintenance_asset_categories" enable row level security;

