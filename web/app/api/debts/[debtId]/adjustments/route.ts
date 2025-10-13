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
      .from('debt_adjustments')
      .select('*')
      .eq('store_id', storeId)
      .eq('debt_id', params.debtId)
      .order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy lịch sử điều chỉnh: ${message}` }, { status: 500 });
  }
}

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

    const payload = await req.json().catch(() => null);

    if (
      !payload ||
      typeof payload !== 'object' ||
      typeof payload.amount !== 'number' ||
      typeof payload.type !== 'string' ||
      typeof payload.reason !== 'string'
    ) {
      return NextResponse.json({ error: 'Thiếu thông tin điều chỉnh' }, { status: 400 });
    }

    if (!['increase', 'decrease', 'write_off'].includes(payload.type)) {
      return NextResponse.json({ error: 'Loại điều chỉnh không hợp lệ' }, { status: 400 });
    }

    if (!payload.reason.trim()) {
      return NextResponse.json({ error: 'Lý do điều chỉnh là bắt buộc' }, { status: 400 });
    }

    const response = await supabaseServer.rpc('adjust_debt_amount', {
      p_debt_id: params.debtId,
      p_adjustment_amount: payload.amount,
      p_adjustment_type: payload.type,
      p_reason: payload.reason,
    });

    return NextResponse.json(response ?? {});
   } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi điều chỉnh công nợ: ${message}` }, { status: 500 });
  }
}
