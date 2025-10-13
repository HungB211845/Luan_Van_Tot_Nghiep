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

    try {
      const { data, error } = await supabaseServer
        .from('low_stock_products')
        .select('*')
        .eq('store_id', storeId)
        .order('current_stock', { ascending: true });

      if (!error && data) {
        return NextResponse.json({ items: data });
      }
    } catch (viewError) {
      console.warn('View low_stock_products unavailable, using fallback:', viewError);
    }

    const { data, error } = await supabaseServer
      .from('products_with_details')
      .select('id, name, sku, category, min_stock_level, available_stock, company_name, is_active')
      .eq('store_id', storeId)
      .eq('is_active', true)
      .order('available_stock', { ascending: true });

    if (error) {
      throw error;
    }

    const items =
      data
        ?.filter((product) => {
          const currentStock = product.available_stock ?? 0;
          const minStock = product.min_stock_level ?? 0;
          return currentStock <= minStock;
        })
        .map((product) => ({
          id: product.id,
          name: product.name,
          sku: product.sku,
          category: product.category,
          min_stock_level: product.min_stock_level,
          current_stock: product.available_stock,
          company_name: product.company_name,
        })) ?? [];

    return NextResponse.json({ items });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

