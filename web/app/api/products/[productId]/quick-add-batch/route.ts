import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    productId: string;
  };
};

export async function POST(req: NextRequest, { params }: RouteParams) {
  const authHeader = req.headers.get('authorization');
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return NextResponse.json({ error: 'Authentication required' }, { status: 401 });
  }

  try {
    const {
      data: { user },
      error: userError,
    } = await supabaseServer.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    const storeId = user.user_metadata?.store_id;

    if (!storeId) {
      return NextResponse.json({ error: 'User is not associated with a store' }, { status: 403 });
    }

    const productId = params.productId;

    if (!productId) {
      return NextResponse.json({ error: 'Product ID is required' }, { status: 400 });
    }

    const payload = await req.json();

    if (!payload || typeof payload !== 'object') {
      return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
    }

    const quantity = Number(payload.quantity);
    const costPrice = Number(payload.costPrice ?? payload.cost_price ?? 0);
    const newSellingPrice = Number(payload.newSellingPrice ?? payload.new_selling_price);
    const unitId = payload.unitId ?? payload.unit_id ?? null;
    const batchNumber = payload.batchNumber ?? payload.batch_number ?? null;
    const expiryDate = payload.expiryDate ?? payload.expiry_date ?? null;

    if (!Number.isFinite(quantity) || quantity <= 0) {
      return NextResponse.json({ error: 'Quantity must be a positive number' }, { status: 400 });
    }

    if (!Number.isFinite(costPrice) || costPrice < 0) {
      return NextResponse.json({ error: 'Cost price must be a non-negative number' }, { status: 400 });
    }

    if (!Number.isFinite(newSellingPrice) || newSellingPrice <= 0) {
      return NextResponse.json({ error: 'New selling price must be a positive number' }, { status: 400 });
    }

    const { error: priceError } = await supabaseServer.rpc('update_product_selling_price', {
      p_product_id: productId,
      p_new_price: newSellingPrice,
      p_reason: payload.reason ?? 'Price updated via Quick Add Batch',
    });

    if (priceError) {
      throw priceError;
    }

    let baseQuantity = quantity;

    if (unitId) {
      const { data: unit, error: unitError } = await supabaseServer
        .from('product_units')
        .select('conversion_factor')
        .eq('id', unitId)
        .eq('store_id', storeId)
        .maybeSingle();

      if (!unitError && unit && typeof unit.conversion_factor === 'number') {
        baseQuantity = quantity * unit.conversion_factor;
      }
    }

    const batchData = {
      product_id: productId,
      batch_number: batchNumber,
      quantity: baseQuantity,
      cost_price: costPrice,
      received_date: payload.receivedDate ?? payload.received_date ?? new Date().toISOString(),
      expiry_date: expiryDate,
      notes: payload.notes ?? null,
      store_id: storeId,
    };

    const { error: insertError } = await supabaseServer
      .from('product_batches')
      .insert(batchData)
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    const { data: product, error: productError } = await supabaseServer
      .from('products_with_details')
      .select('*')
      .eq('id', productId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (productError) {
      throw productError;
    }

    if (!product) {
      throw new Error('Failed to load updated product after quick add batch');
    }

    return NextResponse.json(product, { status: 201 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
