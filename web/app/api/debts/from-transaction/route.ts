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
      !payload.transactionId ||
      typeof payload.amount !== 'number'
    ) {
      return NextResponse.json({ error: 'transactionId và amount là bắt buộc' }, { status: 400 });
    }

    const response = await supabaseServer.rpc('create_credit_sale', {
      p_store_id: storeId,
      p_customer_id: payload.customerId,
      p_transaction_id: payload.transactionId,
      p_amount: payload.amount,
      p_due_date: payload.dueDate ?? null,
      p_notes: payload.notes ?? null,
    });

    if (response == null) {
      return NextResponse.json({ error: 'Không nhận được phản hồi khi tạo công nợ' }, { status: 500 });
    }

    return NextResponse.json({ debtId: response });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi tạo công nợ từ giao dịch: ${message}` }, { status: 500 });
  }
}
