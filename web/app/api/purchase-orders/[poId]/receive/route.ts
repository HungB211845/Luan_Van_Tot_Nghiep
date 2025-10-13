import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function POST(req: NextRequest, { params }: { params: { poId: string } }) {
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

    // Execute RPC to create batches and update pricing
    const { error: rpcError } = await supabaseServer.rpc('create_batches_from_po', {
      po_id: params.poId,
    });

    if (rpcError) {
      throw rpcError;
    }

    const { data: order, error: orderError } = await supabaseServer
      .from('purchase_orders_with_details')
      .select('*')
      .eq('id', params.poId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (orderError) {
      throw orderError;
    }

    if (!order) {
      return NextResponse.json({ error: 'Đơn nhập hàng không tồn tại' }, { status: 404 });
    }

    const { data: productIdsData, error: itemsError } = await supabaseServer
      .from('purchase_order_items')
      .select('product_id')
      .eq('purchase_order_id', params.poId)
      .eq('store_id', storeId);

    if (itemsError) {
      throw itemsError;
    }

    const uniqueProductIds = Array.from(
      new Set((productIdsData ?? []).map((item) => item.product_id as string)),
    );

    const updatedProducts: Record<string, unknown>[] = [];

    for (const productId of uniqueProductIds) {
      const { data: product, error: productError } = await supabaseServer
        .from('products_with_details')
        .select('*')
        .eq('id', productId)
        .eq('store_id', storeId)
        .maybeSingle();

      if (productError) {
        throw productError;
      }

      if (product) {
        updatedProducts.push(product);
      }
    }

    return NextResponse.json({ po: order, products: updatedProducts });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi khi nhận hàng cho đơn nhập: ${message}` }, { status: 500 });
  }
}
