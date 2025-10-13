import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

const RESULT_LIMIT = 10;

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

    const searchParams = req.nextUrl.searchParams;
    const query = searchParams.get('q')?.trim() ?? '';

    if (!query) {
      return NextResponse.json({ items: [] });
    }

    const skuPattern = /^[A-Z0-9]{4,}$/;

    if (skuPattern.test(query.toUpperCase())) {
      const { data: exact, error } = await supabaseServer
        .from('products_with_details')
        .select('*')
        .eq('store_id', storeId)
        .eq('sku', query.toUpperCase())
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

      if (error) {
        throw error;
      }

      if (exact) {
        return NextResponse.json({ items: [exact] });
      }
    }

    const escapedQuery = query.replace(/[%]/g, '\\%').replace(/_/g, '\\_');
    const orFilters = [
      `name.ilike.%${escapedQuery}%`,
      `sku.ilike.%${escapedQuery}%`,
      `description.ilike.%${escapedQuery}%`,
    ].join(',');

    const { data, error } = await supabaseServer
      .from('products_with_details')
      .select('*')
      .eq('store_id', storeId)
      .eq('is_active', true)
      .gt('available_stock', 0)
      .or(orFilters)
      .order('name', { ascending: true })
      .limit(RESULT_LIMIT);

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

