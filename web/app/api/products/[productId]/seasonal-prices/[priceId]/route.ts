import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    productId: string;
    priceId: string;
  };
};

async function authenticate(req: NextRequest) {
  const authHeader = req.headers.get('authorization');
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return { error: NextResponse.json({ error: 'Authentication required' }, { status: 401 }) };
  }

  const {
    data: { user },
    error,
  } = await supabaseServer.auth.getUser(token);

  if (error || !user) {
    return { error: NextResponse.json({ error: 'Invalid token' }, { status: 401 }) };
  }

  const storeId = user.user_metadata?.store_id;

  if (!storeId) {
    return { error: NextResponse.json({ error: 'User is not associated with a store' }, { status: 403 }) };
  }

  return { storeId };
}

export async function PATCH(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }
  const { storeId } = auth;

  const payload = await req.json().catch(() => null);

  if (!payload || typeof payload !== 'object') {
    return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
  }

  const updateData: Record<string, unknown> = {};

  for (const key of ['startDate', 'endDate', 'price', 'isActive', 'notes']) {
    if (key in payload) {
      const dbKey =
        key === 'startDate' ? 'start_date' : key === 'endDate' ? 'end_date' : key === 'isActive' ? 'is_active' : key;
      updateData[dbKey] = payload[key];
    }
  }

  const { data, error } = await supabaseServer
    .from('seasonal_prices')
    .update(updateData)
    .eq('id', params.priceId)
    .eq('product_id', params.productId)
    .eq('store_id', storeId)
    .select()
    .maybeSingle();

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  if (!data) {
    return NextResponse.json({ error: 'Seasonal price not found' }, { status: 404 });
  }

  return NextResponse.json(data);
}

export async function DELETE(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }
  const { storeId } = auth;

  const { error } = await supabaseServer
    .from('seasonal_prices')
    .update({ is_active: false })
    .eq('id', params.priceId)
    .eq('product_id', params.productId)
    .eq('store_id', storeId);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}

