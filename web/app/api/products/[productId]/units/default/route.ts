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
      .eq('is_default_selling_unit', true)
      .maybeSingle();

    if (error) {
      throw error;
    }

    return NextResponse.json({ item: data ?? null });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
