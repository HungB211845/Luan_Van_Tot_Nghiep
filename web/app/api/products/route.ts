import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

// GET /api/products
export async function GET(req: NextRequest) {
  const authHeader = req.headers.get('authorization');
  const token = authHeader?.split(' ')[1];
  const searchParams = req.nextUrl.searchParams;
  const companyId = searchParams.get('companyId');
  const category = searchParams.get('category');
  const limit = Number(searchParams.get('limit') ?? '0');
  const offset = Number(searchParams.get('offset') ?? '0');
  const sortByParam = searchParams.get('sortBy');
  const ascendingParam = searchParams.get('ascending');

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

    const sortableColumns = new Map<string, string>([
      ['name', 'name'],
      ['price', 'current_price'],
      ['stock', 'available_stock'],
      ['created_at', 'created_at'],
      ['updated_at', 'updated_at'],
    ]);

    const sortColumn = sortByParam && sortableColumns.get(sortByParam) ? sortableColumns.get(sortByParam)! : 'name';
    const ascending = ascendingParam !== 'false';

    const from = Math.max(!Number.isNaN(offset) && offset > 0 ? offset : 0, 0);
    const requestedLimit = !Number.isNaN(limit) && limit > 0 ? limit : 50;
    const effectiveLimit = Math.min(requestedLimit, 100);
    const to = from + effectiveLimit - 1;

    const { data: products, error: queryError, count } = await supabaseServer
      .from('products_with_details')
      .select('*', { count: 'exact' })
      .eq('store_id', storeId)
      .modify((builder) => {
        if (companyId) {
          builder.eq('company_id', companyId);
        }
        if (category) {
          builder.eq('category', category);
        }
      })
      .order(sortColumn, { ascending })
      .range(from, to);

    if (queryError) {
      throw queryError;
    }

    const total = count ?? products?.length ?? 0;
    const hasNextPage = total > to + 1;

    return NextResponse.json({
      items: products ?? [],
      totalCount: total,
      offset: from,
      limit: effectiveLimit,
      hasNextPage,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

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

    const payload = await req.json();

    if (!payload || typeof payload !== 'object') {
      return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
    }

    const name = payload.name?.trim();

    if (!name) {
      return NextResponse.json({ error: 'Product name is required' }, { status: 400 });
    }

    const sku = payload.sku?.trim();

    if (sku) {
      const { data: existingSku, error: skuError } = await supabaseServer
        .from('products')
        .select('id')
        .eq('store_id', storeId)
        .eq('sku', sku)
        .maybeSingle();

      if (skuError) {
        throw skuError;
      }

      if (existingSku) {
        return NextResponse.json({ error: `SKU "${sku}" already exists` }, { status: 409 });
      }
    }

    const productData = { ...payload, name, store_id: storeId };
    delete productData.id;
    delete productData.storeId;

    const { data: inserted, error: insertError } = await supabaseServer
      .from('products')
      .insert(productData)
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    const { data: productWithDetails, error: detailError } = await supabaseServer
      .from('products_with_details')
      .select('*')
      .eq('id', inserted.id)
      .eq('store_id', storeId)
      .maybeSingle();

    if (detailError) {
      throw detailError;
    }

    return NextResponse.json(productWithDetails ?? inserted, { status: 201 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
