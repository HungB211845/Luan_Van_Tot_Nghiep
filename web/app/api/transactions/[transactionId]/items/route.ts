import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function GET(
  req: NextRequest,
  { params }: { params: { transactionId: string } },
) {
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
      .from('transaction_items')
      .select(
        `
        id, transaction_id, product_id, batch_id, quantity, price_at_sale, sub_total,
        discount_amount, unit_id, unit_name, unit_conversion_factor, base_unit_quantity,
        created_at, store_id,
        products(name, sku)
      `,
      )
      .eq('transaction_id', params.transactionId)
      .eq('store_id', storeId)
      .order('created_at', { ascending: true });

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy danh sách sản phẩm của giao dịch: ${message}` }, { status: 500 });
  }
}

