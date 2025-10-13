import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    productId: string;
    unitId: string;
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

export async function POST(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;

  try {
    // Unset previous defaults
    const { error: unsetError } = await supabaseServer
      .from('product_units')
      .update({ is_default_selling_unit: false })
      .eq('product_id', params.productId)
      .eq('store_id', storeId);

    if (unsetError) {
      throw unsetError;
    }

    const { data, error } = await supabaseServer
      .from('product_units')
      .update({ is_default_selling_unit: true })
      .eq('id', params.unitId)
      .eq('product_id', params.productId)
      .eq('store_id', storeId)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json(data ?? null);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
