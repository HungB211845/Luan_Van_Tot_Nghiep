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

    const searchParams = req.nextUrl.searchParams;
    const sortBy = searchParams.get('sortBy') ?? 'name';
    const ascending = (searchParams.get('ascending') ?? 'true') !== 'false';

    const allowedSort = new Map<string, string>([
      ['name', 'name'],
      ['debt_limit', 'debt_limit'],
      ['created_at', 'created_at'],
    ]);

    const orderField = allowedSort.get(sortBy) ?? 'name';

    const { data, error } = await supabaseServer
      .from('customers')
      .select('*')
      .eq('store_id', storeId)
      .order(orderField, { ascending });

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy danh sách khách hàng: ${message}` }, { status: 500 });
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

    const payload = await req.json().catch(() => null);

    if (!payload || typeof payload !== 'object') {
      return NextResponse.json({ error: 'Invalid payload' }, { status: 400 });
    }

    const insertData = {
      ...payload,
      store_id: storeId,
    };

    const { data, error } = await supabaseServer
      .from('customers')
      .insert(insertData)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json(data, { status: 201 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi tạo khách hàng mới: ${message}` }, { status: 500 });
  }
}
