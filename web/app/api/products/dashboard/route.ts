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

    const { count: totalProducts, error: totalError } = await supabaseServer
      .from('products')
      .select('id', { count: 'exact', head: true })
      .eq('store_id', storeId)
      .eq('is_active', true);

    if (totalError) {
      throw totalError;
    }

    let lowStockCount = 0;
    try {
      const { count, error } = await supabaseServer
        .from('low_stock_products')
        .select('id', { count: 'exact', head: true })
        .eq('store_id', storeId)
        .eq('is_active', true);
      if (error) {
        throw error;
      }
      lowStockCount = count ?? 0;
    } catch {
      const { data } = await supabaseServer
        .from('products_with_details')
        .select('available_stock, min_stock_level')
        .eq('store_id', storeId)
        .eq('is_active', true);
      lowStockCount =
        data?.filter((p) => (p.available_stock ?? 0) <= (p.min_stock_level ?? 0)).length ?? 0;
    }

    let expiringCount = 0;
    try {
      const { count, error } = await supabaseServer
        .from('expiring_batches')
        .select('id', { count: 'exact', head: true })
        .eq('store_id', storeId);
      if (error) {
        throw error;
      }
      expiringCount = count ?? 0;
    } catch {
      const futureDate = new Date();
      futureDate.setMonth(futureDate.getMonth() + 1);
      const { data } = await supabaseServer
        .from('product_batches')
        .select('expiry_date')
        .eq('store_id', storeId)
        .eq('is_available', true)
        .not('expiry_date', 'is', null)
        .lte('expiry_date', futureDate.toISOString().split('T')[0]);
      expiringCount = data?.length ?? 0;
    }

    return NextResponse.json({
      total_products: totalProducts ?? 0,
      low_stock_count: lowStockCount,
      expiring_batches_count: expiringCount,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
