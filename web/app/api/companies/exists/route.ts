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
    const name = searchParams.get('name')?.trim();
    const excludeId = searchParams.get('excludeId');

    if (!name) {
      return NextResponse.json({ exists: false });
    }

    const normalizedName = name.replace(/\s+/g, ' ');

    const { data, error } = await supabaseServer
      .from('companies')
      .select('id')
      .eq('store_id', storeId)
      .eq('is_active', true)
      .ilike('name', normalizedName);

    if (error) {
      throw error;
    }

    const list = data ?? [];
    const exists = excludeId
      ? list.some((row) => row.id !== excludeId)
      : list.length > 0;

    return NextResponse.json({ exists });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi kiểm tra tên nhà cung cấp: ${message}` }, { status: 500 });
  }
}
