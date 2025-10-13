import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    poId: string;
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
    const { data: order, error } = await supabaseServer
      .from('purchase_orders_with_details')
      .select('*')
      .eq('id', params.poId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!order) {
      return NextResponse.json({ error: 'Đơn nhập hàng không tồn tại' }, { status: 404 });
    }

    const { data: items, error: itemsError } = await supabaseServer
      .from('purchase_order_items')
      .select('id,purchase_order_id,product_id,quantity,unit_cost,unit,total_cost,received_quantity,notes,created_at, products(name)')
      .eq('purchase_order_id', params.poId)
      .eq('store_id', storeId);

    if (itemsError) {
      throw itemsError;
    }

    return NextResponse.json({ order, items: items ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy chi tiết đơn nhập hàng: ${message}` }, { status: 500 });
  }
}
