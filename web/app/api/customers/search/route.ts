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

    const query = req.nextUrl.searchParams.get('q')?.trim() ?? '';

    if (!query) {
      return NextResponse.json({ items: [] });
    }

    const escaped = query.replace(/[%]/g, '\\%').replace(/_/g, '\\_');

    const { data, error } = await supabaseServer
      .from('customers')
      .select('*')
      .eq('store_id', storeId)
      .or(
        `name.ilike.%${escaped}%,phone.ilike.%${escaped}%,address.ilike.%${escaped}%`,
      )
      .order('name', { ascending: true });

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi tìm kiếm khách hàng: ${message}` }, { status: 500 });
  }
}
