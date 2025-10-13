import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

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
      return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
    }

    const activeIngredient = String(payload.activeIngredient ?? payload.active_ingredient ?? '').trim();

    if (!activeIngredient) {
      return NextResponse.json({ error: 'activeIngredient is required' }, { status: 400 });
    }

    const { data, error } = await supabaseServer
      .from('banned_substances')
      .select('active_ingredient_name')
      .eq('store_id', storeId)
      .eq('is_active', true)
      .ilike('active_ingredient_name', activeIngredient);

    if (error) {
      throw error;
    }

    const isBanned = (data ?? []).some((item) => item.active_ingredient_name?.toLowerCase() === activeIngredient.toLowerCase());

    return NextResponse.json({ isBanned });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

