import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    productId: string;
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

export async function GET(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;

  try {
    const { data, error } = await supabaseServer
      .from('product_units')
      .select('*')
      .eq('store_id', storeId)
      .eq('product_id', params.productId)
      .eq('is_active', true)
      .order('is_default_selling_unit', { ascending: false })
      .order('unit_name', { ascending: true });

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function POST(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;

  const payload = await req.json().catch(() => null);

  if (!payload || typeof payload !== 'object') {
    return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
  }

  const unitData = {
    ...payload,
    product_id: params.productId,
    store_id: storeId,
  };

  delete (unitData as Record<string, unknown>).id;

  try {
    const { data, error } = await supabaseServer
      .from('product_units')
      .insert(unitData)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json(data, { status: 201 });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

