import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function GET(req: NextRequest, { params }: { params: { companyId: string } }) {
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

    const { count, error } = await supabaseServer
      .from('purchase_orders')
      .select('id', { count: 'exact', head: true })
      .eq('supplier_id', params.companyId)
      .eq('store_id', storeId);

    if (error) {
      throw error;
    }

    return NextResponse.json({ hasPurchaseOrders: (count ?? 0) > 0 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi kiểm tra đơn nhập hàng của nhà cung cấp: ${message}` }, { status: 500 });
  }
}
