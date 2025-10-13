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

    if (
      !payload ||
      typeof payload !== 'object' ||
      !payload.customerId ||
      typeof payload.amount !== 'number'
    ) {
      return NextResponse.json({ error: 'customerId và amount là bắt buộc' }, { status: 400 });
    }

    const response = await supabaseServer.rpc('process_customer_payment', {
      p_store_id: storeId,
      p_customer_id: payload.customerId,
      p_payment_amount: payload.amount,
      p_payment_method: payload.paymentMethod ?? 'CASH',
      p_notes: payload.notes ?? null,
    });

    return NextResponse.json(response ?? {});
   } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi xử lý thanh toán: ${message}` }, { status: 500 });
  }
}
