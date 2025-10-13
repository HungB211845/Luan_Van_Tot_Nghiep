import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function GET(req: NextRequest) {
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

    const now = new Date();
    const startOfDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const endOfDay = new Date(startOfDay);
    endOfDay.setUTCDate(startOfDay.getUTCDate() + 1);

    const startIso = startOfDay.toISOString();
    const endIso = endOfDay.toISOString();

    const { data, error } = await supabaseServer
      .from('transactions')
      .select('total_amount')
      .eq('store_id', storeId)
      .gte('transaction_date', startIso)
      .lt('transaction_date', endIso);

    if (error) {
      throw error;
    }

    const totals = (data ?? []).reduce(
      (acc, row) => {
        const amount = Number(row.total_amount ?? 0);
        if (Number.isFinite(amount)) {
          acc.today_revenue += amount;
        }
        acc.today_transactions += 1;
        return acc;
      },
      { today_revenue: 0, today_transactions: 0 },
    );

    return NextResponse.json(totals);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy thống kê giao dịch hôm nay: ${message}` }, { status: 500 });
  }
}
