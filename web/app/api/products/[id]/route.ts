import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

// GET /api/products/[id]
export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
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

    const { data: product, error: queryError } = await supabaseServer
      .from('products_with_details')
      .select('*')
      .eq('store_id', storeId)
      .eq('id', params.id)
      .maybeSingle();

    if (queryError) {
      throw queryError;
    }

    if (!product) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 });
    }

    return NextResponse.json(product);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
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

    const productId = params.id;

    const { error: updateError } = await supabaseServer
      .from('products')
      .update({ is_active: false })
      .eq('id', productId)
      .eq('store_id', storeId);

    if (updateError) {
      throw updateError;
    }

    return NextResponse.json({ success: true });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
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

    const productId = params.id;

    const payload = await req.json();

    if (!payload || typeof payload !== 'object') {
      return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
    }

    const name = payload.name?.trim();

    if (!name) {
      return NextResponse.json({ error: 'Product name is required' }, { status: 400 });
    }

    const sku = payload.sku?.trim();

    if (sku) {
      const { data: existingSku, error: skuError } = await supabaseServer
        .from('products')
        .select('id')
        .eq('store_id', storeId)
        .eq('sku', sku)
        .neq('id', productId)
        .maybeSingle();

      if (skuError) {
        throw skuError;
      }

      if (existingSku) {
        return NextResponse.json({ error: `SKU "${sku}" already exists` }, { status: 409 });
      }
    }

    const updateData = { ...payload, name };
    delete updateData.id;
    delete updateData.store_id;
    delete updateData.storeId;

    const { data: updated, error: updateError } = await supabaseServer
      .from('products')
      .update(updateData)
      .eq('id', productId)
      .eq('store_id', storeId)
      .select()
      .maybeSingle();

    if (updateError) {
      throw updateError;
    }

    if (!updated) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 });
    }

    const { data: productWithDetails, error: detailError } = await supabaseServer
      .from('products_with_details')
      .select('*')
      .eq('id', productId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (detailError) {
      throw detailError;
    }

    return NextResponse.json(productWithDetails ?? updated);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
