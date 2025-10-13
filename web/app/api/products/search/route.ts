import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

function parseNumber(value: string | null): number | null {
  if (!value?.trim()) {
    return null;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

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
    const category = searchParams.get('category')?.trim();
    const minPrice = parseNumber(searchParams.get('minPrice'));
    const maxPrice = parseNumber(searchParams.get('maxPrice'));
    const inStock = searchParams.get('inStock') === 'true';
    const limitParam = parseNumber(searchParams.get('limit'));
    const offsetParam = parseNumber(searchParams.get('offset'));

    const limit = Math.max(1, Math.min(limitParam ?? DEFAULT_LIMIT, MAX_LIMIT));
    const offset = Math.max(0, offsetParam ?? 0);

    if (!query) {
      return NextResponse.json({ items: [], totalCount: 0, offset, limit, hasNextPage: false });
    }

    const escapedQuery = query.replace(/[%]/g, '\\%').replace(/_/g, '\\_');
    const orFilters = [
      `name.ilike.%${escapedQuery}%`,
      `sku.ilike.%${escapedQuery}%`,
      `description.ilike.%${escapedQuery}%`,
    ].join(',');

    let builder = supabaseServer
      .from('products_with_details')
      .select('*', { count: 'exact' })
      .eq('store_id', storeId)
      .eq('is_active', true)
      .or(orFilters);

    if (category) {
      builder = builder.eq('category', category);
    }

    if (minPrice !== null) {
      builder = builder.gte('current_price', minPrice);
    }

    if (maxPrice !== null) {
      builder = builder.lte('current_price', maxPrice);
    }

    if (inStock) {
      builder = builder.gt('available_stock', 0);
    }

    const from = offset;
    const to = offset + limit - 1;

    const { data, error: queryError, count } = await builder
      .order('name', { ascending: true })
      .range(from, to);

    if (queryError) {
      throw queryError;
    }

    const safeCount = count ?? data?.length ?? 0;

    return NextResponse.json({
      items: data ?? [],
      totalCount: safeCount,
      offset,
      limit,
      hasNextPage: safeCount > to + 1,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
