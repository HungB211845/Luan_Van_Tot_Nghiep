import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

function parseNumber(value: string | null): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

type RouteParams = { params: { productId: string } };

export async function GET(req: NextRequest, { params }: RouteParams) {
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

    const searchParams = req.nextUrl.searchParams;
    const limit = Math.max(1, Math.min(parseNumber(searchParams.get('limit')) || DEFAULT_LIMIT, MAX_LIMIT));
    const offset = Math.max(0, parseNumber(searchParams.get('offset')));

    const from = offset;
    const to = offset + limit - 1;

    const { data, error: queryError, count } = await supabaseServer
      .from('product_batches')
      .select('*', { count: 'exact' })
      .eq('store_id', storeId)
      .eq('product_id', productId)
      .eq('is_available', true)
      .gt('quantity', 0)
      .order('received_date', { ascending: false })
      .range(from, to);

    if (queryError) {
      throw queryError;
    }

    const total = count ?? data?.length ?? 0;
    const hasNextPage = total > to + 1;

    return NextResponse.json({
      items: data ?? [],
      totalCount: total,
      offset,
      limit,
      hasNextPage,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

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

    const batchData = {
      batch_number: payload.batch_number ?? null,
      quantity: payload.quantity,
      cost_price: payload.cost_price,
      product_id: productId,
      supplier_id: payload.supplier_id ?? null,
      received_date: payload.received_date ?? new Date().toISOString(),
      expiry_date: payload.expiry_date ?? null,
      notes: payload.notes ?? null,
      is_available: payload.is_available ?? true,
      store_id: storeId,
    };

    if (typeof batchData.quantity !== 'number' || batchData.quantity <= 0) {
      return NextResponse.json({ error: 'Quantity must be a positive number' }, { status: 400 });
    }

    if (typeof batchData.cost_price !== 'number' || batchData.cost_price < 0) {
      return NextResponse.json({ error: 'Cost price must be a non-negative number' }, { status: 400 });
    }

    const { data, error: insertError } = await supabaseServer
      .from('product_batches')
      .insert(batchData)
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    return NextResponse.json(data, { status: 201 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
