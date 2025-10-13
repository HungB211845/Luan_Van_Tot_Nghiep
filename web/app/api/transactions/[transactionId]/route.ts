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

    const includeParam = req.nextUrl.searchParams.get('include');
    const includeItems =
      includeParam?.toLowerCase() === 'items' ||
      includeParam?.split(',').map((value) => value.trim().toLowerCase()).includes('items');

    const selectColumns = includeItems
      ? `
        id, store_id, customer_id, total_amount, surcharge_amount, transaction_date,
        is_debt, payment_method, notes, invoice_number, created_by, created_at,
        customers(name),
        transaction_items(
          id, product_id, batch_id, quantity, price_at_sale, sub_total, discount_amount,
          unit_id, unit_name, unit_conversion_factor, base_unit_quantity, created_at,
          products(name, sku)
        )
      `
      : `
        id, store_id, customer_id, total_amount, surcharge_amount, transaction_date,
        is_debt, payment_method, notes, invoice_number, created_by, created_at,
        customers(name)
      `;

    const { data, error } = await supabaseServer
      .from('transactions')
      .select(selectColumns)
      .eq('store_id', storeId)
      .eq('id', params.transactionId)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return NextResponse.json({ error: 'Transaction not found' }, { status: 404 });
    }

    return NextResponse.json(data);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy thông tin giao dịch: ${message}` }, { status: 500 });
  }
}

