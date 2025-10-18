-- Migration: Update replace_product_units RPC to handle existing unit names
-- Purpose: Prevent unique constraint violations by upserting units instead of
--          blindly inserting duplicates. Ensures that historical units not
--          present in the new configuration remain inactive while the provided
--          units are reactivated with refreshed data.

create or replace function public.replace_product_units(
  p_product_id uuid,
  p_new_units jsonb[]
) returns void
language plpgsql
security definer
as $$
declare
  v_unit jsonb;
  v_store_id uuid;
begin
  if p_product_id is null then
    raise exception 'replace_product_units: product id is required';
  end if;

  -- Fetch store id for security / multi-tenant safety
  select store_id
    into v_store_id
    from public.products
   where id = p_product_id
   limit 1;

  if v_store_id is null then
    raise exception 'replace_product_units: product % not found or missing store', p_product_id;
  end if;

  -- Deactivate all existing units for this product
  update public.product_units
     set is_active = false,
         is_default_selling_unit = false,
         updated_at = now()
   where product_id = p_product_id
     and store_id = v_store_id;

  -- Upsert provided units so unique constraint is preserved while data refreshes
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
      trim(coalesce(nullif(v_unit ->> 'unit_name', ''), 'Đơn vị')),
      (v_unit ->> 'conversion_factor')::numeric,
      (v_unit ->> 'unit_price')::numeric,
      coalesce((v_unit ->> 'is_default_selling_unit')::boolean, false),
      true, -- All supplied units must be active
      coalesce((v_unit ->> 'store_id')::uuid, v_store_id),
      coalesce((v_unit ->> 'created_at')::timestamptz, now()),
      now()
    )
    on conflict (product_id, unit_name, store_id)
    do update
      set conversion_factor = excluded.conversion_factor,
          unit_price = excluded.unit_price,
          is_default_selling_unit = excluded.is_default_selling_unit,
          is_active = true,
          updated_at = now();
  end loop;
end;
$$;

-- Ensure authenticated role can execute the refreshed function
grant execute on function public.replace_product_units(uuid, jsonb[]) to authenticated;
