import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
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

  const updateData = { ...payload };
  delete (updateData as Record<string, unknown>).product_id;
  delete (updateData as Record<string, unknown>).store_id;

  try {
    const { data, error } = await supabaseServer
      .from('product_units')
      .update(updateData)
      .eq('id', params.unitId)
      .eq('store_id', storeId)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json(data);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;

  try {
    const { data: unit, error: fetchError } = await supabaseServer
      .from('product_units')
      .select('product_id')
      .eq('id', params.unitId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (fetchError) {
      throw fetchError;
    }

    if (!unit?.product_id) {
      return NextResponse.json({ error: 'Product unit not found' }, { status: 404 });
    }

    const { count: activeCount, error: countError } = await supabaseServer
      .from('product_units')
      .select('id', { count: 'exact', head: true })
      .eq('product_id', unit.product_id)
      .eq('store_id', storeId)
      .eq('is_active', true);

    if (countError) {
      throw countError;
    }

    if ((activeCount ?? 0) <= 1) {
      return NextResponse.json({ error: 'Không thể xóa đơn vị cuối cùng của sản phẩm' }, { status: 400 });
    }

    const { error } = await supabaseServer
      .from('product_units')
      .update({ is_active: false })
      .eq('id', params.unitId)
      .eq('store_id', storeId);

    if (error) {
      throw error;
    }

    return NextResponse.json({ success: true });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
