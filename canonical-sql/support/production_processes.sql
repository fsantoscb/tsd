create table public."production_processes" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "sequence" integer not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_processes_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "production_processes_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_processes_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_processes_pkey" PRIMARY KEY (id)
);
alter table public."production_processes" enable row level security;

