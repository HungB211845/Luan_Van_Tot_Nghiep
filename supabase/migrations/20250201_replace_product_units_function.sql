-- Migration: replace_product_units RPC
-- Purpose: Atomically deactivate existing units and insert refreshed configuration

create or replace function public.replace_product_units(
  p_product_id uuid,
  p_new_units jsonb[]
) returns void
language plpgsql
security definer
as $$
declare
  v_unit jsonb;
begin
  if p_product_id is null then
    raise exception 'replace_product_units: product id is required';
  end if;

  -- Deactivate all existing units for this product in a single shot
  update public.product_units
     set is_active = false,
         updated_at = now()
   where product_id = p_product_id;

  -- Insert the incoming units
  foreach v_unit in array p_new_units loop
    insert into public.product_units (
      product_id,
      unit_name,
      conversion_factor,
      unit_price,
      is_default_selling_unit,
      is_active,
      store_id,
      created_at,
      updated_at
    )
    values (
      p_product_id,
      (v_unit ->> 'unit_name')::text,
      (v_unit ->> 'conversion_factor')::numeric,
      (v_unit ->> 'unit_price')::numeric,
      coalesce((v_unit ->> 'is_default_selling_unit')::boolean, false),
      coalesce((v_unit ->> 'is_active')::boolean, true),
      (v_unit ->> 'store_id')::uuid,
      coalesce((v_unit ->> 'created_at')::timestamptz, now()),
      now()
    );
  end loop;
end;
$$;
