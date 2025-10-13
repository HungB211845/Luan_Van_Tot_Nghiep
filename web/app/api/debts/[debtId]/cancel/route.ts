import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function POST(req: NextRequest, { params }: { params: { debtId: string } }) {
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

    if (!payload || typeof payload !== 'object' || !payload.reason?.trim()) {
      return NextResponse.json({ error: 'reason là bắt buộc' }, { status: 400 });
    }

    const { error } = await supabaseServer
      .from('debts')
      .update({
        status: 'cancelled',
        notes: `Đã hủy: ${payload.reason}`,
        updated_at: new Date().toISOString(),
      })
      .eq('id', params.debtId)
      .eq('store_id', storeId);

    if (error) {
      throw error;
    }

    return NextResponse.json({ success: true });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi hủy công nợ: ${message}` }, { status: 500 });
  }
}
