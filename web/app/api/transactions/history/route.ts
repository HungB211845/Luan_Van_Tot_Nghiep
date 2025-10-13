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

    const searchParams = req.nextUrl.searchParams;
    const customerId = searchParams.get('customerId');
    const limitRaw = Number(searchParams.get('limit'));
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 200) : 50;

    const query = supabaseServer
      .from('transactions')
      .select(
        `
        id, store_id, customer_id, total_amount, surcharge_amount, transaction_date,
        is_debt, payment_method, notes, invoice_number, created_by, created_at,
        customers(name)
      `,
      )
      .eq('store_id', storeId)
      .order('transaction_date', { ascending: false })
      .limit(limit);

    const { data, error } = customerId ? await query.eq('customer_id', customerId) : await query;

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy lịch sử giao dịch: ${message}` }, { status: 500 });
  }
}

