import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    productId: string;
    batchId: string;
  };
};

export async function PATCH(req: NextRequest, { params }: RouteParams) {
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

    const { productId, batchId } = params;

    if (!productId || !batchId) {
      return NextResponse.json({ error: 'Product ID and batch ID are required' }, { status: 400 });
    }

    const payload = await req.json();

    if (!payload || typeof payload !== 'object') {
      return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
    }

    const updateData = {
      ...(payload.batch_number !== undefined ? { batch_number: payload.batch_number } : {}),
      ...(payload.quantity !== undefined ? { quantity: payload.quantity } : {}),
      ...(payload.cost_price !== undefined ? { cost_price: payload.cost_price } : {}),
      ...(payload.supplier_id !== undefined ? { supplier_id: payload.supplier_id } : {}),
      ...(payload.received_date !== undefined ? { received_date: payload.received_date } : {}),
      ...(payload.expiry_date !== undefined ? { expiry_date: payload.expiry_date } : {}),
      ...(payload.notes !== undefined ? { notes: payload.notes } : {}),
      ...(payload.is_available !== undefined ? { is_available: payload.is_available } : {}),
    };

    if ('quantity' in updateData) {
      const quantity = Number(updateData.quantity);
      if (!Number.isFinite(quantity) || quantity < 0) {
        return NextResponse.json({ error: 'Quantity must be a non-negative number' }, { status: 400 });
      }
      updateData.quantity = quantity;
    }

    if ('cost_price' in updateData) {
      const costPrice = Number(updateData.cost_price);
      if (!Number.isFinite(costPrice) || costPrice < 0) {
        return NextResponse.json({ error: 'Cost price must be a non-negative number' }, { status: 400 });
      }
      updateData.cost_price = costPrice;
    }

    const { data, error: updateError } = await supabaseServer
      .from('product_batches')
      .update(updateData)
      .eq('id', batchId)
      .eq('product_id', productId)
      .eq('store_id', storeId)
      .select()
      .single();

    if (updateError) {
      throw updateError;
    }

    return NextResponse.json(data);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

