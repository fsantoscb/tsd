create table public."products" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sku" text not null,
  "description" text,
  "product_family_id" uuid,
  "product_type_id" uuid,
  "decoration_method" text,
  "default_routing_id" uuid,
  "source_system" text,
  "source_product_code" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "products_default_routing_organization_fkey" FOREIGN KEY (organization_id, default_routing_id) REFERENCES routings(organization_id, id),
  constraint "products_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "products_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "products_organization_id_product_family_id_fkey" FOREIGN KEY (organization_id, product_family_id) REFERENCES product_families(organization_id, id),
  constraint "products_organization_id_product_type_id_fkey" FOREIGN KEY (organization_id, product_type_id) REFERENCES product_types(organization_id, id),
  constraint "products_organization_id_sku_key" UNIQUE (organization_id, sku),
  constraint "products_pkey" PRIMARY KEY (id)
);
CREATE INDEX products_classification_idx ON public.products USING btree (organization_id, product_family_id, product_type_id);
CREATE INDEX products_default_routing_idx ON public.products USING btree (organization_id, default_routing_id);
alter table public."products" enable row level security;
create policy "products_manage" on public."products" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "products_read" on public."products" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active))));
CREATE TRIGGER product_routing_assignment_audit_change AFTER UPDATE OF default_routing_id ON products FOR EACH ROW WHEN (old.default_routing_id IS DISTINCT FROM new.default_routing_id) EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER validate_product_default_routing_change BEFORE INSERT OR UPDATE OF default_routing_id, organization_id ON products FOR EACH ROW EXECUTE FUNCTION validate_product_default_routing();

