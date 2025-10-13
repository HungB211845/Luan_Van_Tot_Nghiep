import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function GET(req: NextRequest, { params }: { params: { batchId: string } }) {
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

    const { data: batch, error } = await supabaseServer
      .from('product_batches')
      .select('sales_count')
      .eq('id', params.batchId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!batch) {
      return NextResponse.json({ error: 'Lô hàng không tồn tại' }, { status: 404 });
    }

    const salesCount = Number(batch.sales_count ?? 0);
    const canEdit = salesCount === 0;
    const canDelete = canEdit;

    return NextResponse.json({ canEdit, canDelete });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi kiểm tra quyền lô hàng: ${message}` }, { status: 500 });
  }
}
