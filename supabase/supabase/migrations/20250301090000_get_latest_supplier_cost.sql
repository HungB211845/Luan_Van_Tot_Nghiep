-- =============================================================================
-- MIGRATION: Create get_latest_supplier_cost RPC
-- Purpose : Provide latest purchase cost per product for a supplier
-- =============================================================================

create or replace function public.get_latest_supplier_cost(
  p_supplier_id uuid,
  p_product_ids uuid[]
)
returns table(
  product_id uuid,
  last_unit_cost numeric,
  last_po_date timestamptz
)
language plpgsql
security definer
as $function$
declare
  v_store_id uuid;
begin
  select store_id
    into v_store_id
  from user_profiles
  where id = auth.uid();

  if v_store_id is null then
    raise exception 'User is not linked to any store';
  end if;

  return query
  select distinct on (poi.product_id)
    poi.product_id,
    poi.unit_cost,
    coalesce(
      po.delivery_date::timestamptz,
      po.order_date::timestamptz,
      poi.created_at
    ) as last_po_date
  from purchase_order_items poi
  join purchase_orders po
    on po.id = poi.purchase_order_id
  where po.store_id = v_store_id
    and poi.quantity > 0
    and upper(po.status) in ('DELIVERED', 'CONFIRMED')
    and (p_supplier_id is null or po.supplier_id = p_supplier_id)
    and (p_product_ids is null or poi.product_id = any(p_product_ids))
  order by poi.product_id,
           coalesce(
             po.delivery_date::timestamptz,
             po.order_date::timestamptz,
             poi.created_at
           ) desc,
           poi.created_at desc;
end;
$function$;

grant execute on function public.get_latest_supplier_cost(uuid, uuid[]) to authenticated;
