import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function GET(req: NextRequest, { params }: { params: { debtId: string } }) {
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

    const { data, error } = await supabaseServer
      .from('debt_payments')
      .select('*')
      .eq('store_id', storeId)
      .eq('debt_id', params.debtId)
      .order('payment_date', { ascending: false });

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy lịch sử thanh toán: ${message}` }, { status: 500 });
  }
}
