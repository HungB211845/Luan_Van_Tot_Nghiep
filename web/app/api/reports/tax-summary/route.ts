import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

function parseDateParam(value: string | null, name: string) {
  if (!value) {
    throw new Error(`Missing "${name}" query parameter`);
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid "${name}" query parameter`);
  }
  return date.toISOString();
}

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

    const searchParams = req.nextUrl.searchParams;
    let startIso: string;
    let endIso: string;

    try {
      startIso = parseDateParam(searchParams.get('start'), 'start');
      endIso = parseDateParam(searchParams.get('end'), 'end');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid date parameters';
      return NextResponse.json({ error: message }, { status: 400 });
    }

    const [transactionsResponse, purchaseOrdersResponse] = await Promise.all([
      supabaseServer
        .from('transactions')
        .select('total_amount', { count: 'exact' })
        .eq('store_id', storeId)
        .gte('created_at', startIso)
        .lte('created_at', endIso),
      supabaseServer
        .from('purchase_orders')
        .select('total_amount')
        .eq('store_id', storeId)
        .eq('status', 'DELIVERED')
        .gte('delivery_date', startIso)
        .lte('delivery_date', endIso),
    ]);

    if (transactionsResponse.error) {
      throw transactionsResponse.error;
    }
    if (purchaseOrdersResponse.error) {
      throw purchaseOrdersResponse.error;
    }

    const transactions = transactionsResponse.data ?? [];
    const purchaseOrders = purchaseOrdersResponse.data ?? [];

    const totalRevenue = transactions.reduce((sum, row) => {
      const amount = Number(row.total_amount ?? 0);
      return Number.isFinite(amount) ? sum + amount : sum;
    }, 0);

    const totalTransactions = transactionsResponse.count ?? transactions.length;

    const totalExpenses = purchaseOrders.reduce((sum, row) => {
      const amount = Number(row.total_amount ?? 0);
      return Number.isFinite(amount) ? sum + amount : sum;
    }, 0);

    const estimatedTax = totalRevenue * 0.015;

    return NextResponse.json({
      total_revenue: totalRevenue,
      total_transactions: totalTransactions,
      total_expenses: totalExpenses,
      estimated_tax: estimatedTax,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy báo cáo thuế: ${message}` }, { status: 500 });
  }
}

