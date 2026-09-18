create or replace view public."v_manufacturing_order_product_mix" as
 SELECT po.organization_id,
    po.id AS manufacturing_order_id,
    po.mo_number,
    po.source_order_no,
    po.routing_code_snapshot,
    l.product_id,
    p.sku,
    p.description,
    (sum(l.planned_quantity))::numeric(14,3) AS planned_quantity,
    round(((sum(l.planned_quantity) / NULLIF(po.planned_quantity, (0)::numeric)) * (100)::numeric), 1) AS mix_percent
   FROM ((production_orders po
     JOIN manufacturing_order_lines l ON ((l.manufacturing_order_id = po.id)))
     LEFT JOIN products p ON (((p.id = l.product_id) AND (p.organization_id = l.organization_id))))
  GROUP BY po.organization_id, po.id, po.mo_number, po.source_order_no, po.routing_code_snapshot, l.product_id, p.sku, p.description, po.planned_quantity;;

