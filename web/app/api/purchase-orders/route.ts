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

    const { data, error } = await supabaseServer
      .from('purchase_orders_with_details')
      .select('*')
      .eq('store_id', storeId)
      .order('order_date', { ascending: false });

    if (error) {
      throw error;
    }

    return NextResponse.json({ items: data ?? [] });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy danh sách đơn nhập hàng: ${message}` }, { status: 500 });
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

    const { order, items } = payload as { order: Record<string, unknown>; items: Record<string, unknown>[] };

    if (!order || !Array.isArray(items) || items.length === 0) {
      return NextResponse.json({ error: 'Thiếu thông tin đơn nhập hoặc danh sách sản phẩm' }, { status: 400 });
    }

    const sanitizedOrder = { ...order };
    delete sanitizedOrder.id;
    sanitizedOrder.store_id = storeId;

    const { data: insertedOrder, error: insertOrderError } = await supabaseServer
      .from('purchase_orders')
      .insert(sanitizedOrder)
      .select()
      .single();

    if (insertOrderError) {
      throw insertOrderError;
    }

    const orderId = insertedOrder.id as string;

    const itemsToInsert = items.map((item) => {
      const copy = { ...item };
      delete copy.id;
      return {
        ...copy,
        purchase_order_id: orderId,
        store_id: storeId,
      };
    });

    const { error: insertItemsError } = await supabaseServer
      .from('purchase_order_items')
      .insert(itemsToInsert);

    if (insertItemsError) {
      throw insertItemsError;
    }

    return NextResponse.json(insertedOrder, { status: 201 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi tạo đơn nhập hàng: ${message}` }, { status: 500 });
  }
}
