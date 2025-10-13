import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function POST(req: NextRequest, { params }: { params: { batchId: string } }) {
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
      return NextResponse.json({ error: 'reason is required' }, { status: 400 });
    }

    const { data: batch, error: batchError } = await supabaseServer
      .from('product_batches')
      .select('quantity, sales_count, product_id')
      .eq('id', params.batchId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (batchError) {
      throw batchError;
    }

    if (!batch) {
      return NextResponse.json({ error: 'Lô hàng không tồn tại' }, { status: 404 });
    }

    const currentQuantity = Number(batch.quantity ?? 0);
    if (currentQuantity <= 0) {
      return NextResponse.json({ error: 'Lô hàng đã hết, không thể hủy' }, { status: 400 });
    }

    const salesCount = Number(batch.sales_count ?? 0);

    const adjustmentData = {
      batch_id: params.batchId,
      quantity_change: -currentQuantity,
      reason: payload.reason,
      adjustment_type: 'void_batch',
      user_id_who_adjusted: user.id,
      notes: salesCount > 0
        ? `Hủy lô hàng đã có ${salesCount} giao dịch bán`
        : 'Hủy lô hàng chưa có giao dịch',
      store_id: storeId,
    };

    const { error: adjustError } = await supabaseServer
      .from('inventory_adjustments')
      .insert(adjustmentData);

    if (adjustError) {
      throw adjustError;
    }

    const { error: updateError } = await supabaseServer
      .from('product_batches')
      .update({
        is_deleted: true,
        quantity: 0,
        updated_at: new Date().toISOString(),
      })
      .eq('id', params.batchId)
      .eq('store_id', storeId);

    if (updateError) {
      throw updateError;
    }

    return NextResponse.json({ success: true });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi hủy lô hàng: ${message}` }, { status: 500 });
  }
}
