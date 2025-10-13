import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
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

    const payload = await req.json().catch(() => null);

    if (!payload || typeof payload !== 'object' || !payload.customerId) {
      return NextResponse.json({ error: 'customerId is required' }, { status: 400 });
    }

    const { data, error } = await supabaseServer.rpc('get_customer_statistics', {
      p_customer_id: payload.customerId,
      p_store_id: storeId,
    });

    if (error) {
      throw error;
    }

    if (data == null) {
      return NextResponse.json({
        transaction_count: 0,
        total_revenue: 0,
        outstanding_debt: 0,
      });
    }

    if (typeof data === 'string') {
      return NextResponse.json(JSON.parse(data));
    }

    return NextResponse.json(data);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy thống kê khách hàng: ${message}` }, { status: 500 });
  }
}
