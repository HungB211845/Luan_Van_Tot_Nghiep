import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    companyId: string;
  };
};

async function authenticate(req: NextRequest) {
  const authHeader = req.headers.get('authorization');
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return { error: NextResponse.json({ error: 'Authentication required' }, { status: 401 }) };
  }

  const {
    data: { user },
    error,
  } = await supabaseServer.auth.getUser(token);

  if (error || !user) {
    return { error: NextResponse.json({ error: 'Invalid token' }, { status: 401 }) };
  }

  const storeId = user.user_metadata?.store_id;

  if (!storeId) {
    return { error: NextResponse.json({ error: 'User is not associated with a store' }, { status: 403 }) };
  }

  return { storeId };
}

export async function PUT(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;
  const payload = await req.json().catch(() => null);

  if (!payload || typeof payload !== 'object') {
    return NextResponse.json({ error: 'Invalid payload' }, { status: 400 });
  }

  const normalizedName = String(payload.name ?? '').trim().replace(/\s+/g, ' ');

  if (!normalizedName) {
    return NextResponse.json({ error: 'Tên nhà cung cấp là bắt buộc' }, { status: 400 });
  }

  try {
    const { data: dupList, error: dupError } = await supabaseServer
      .from('companies')
      .select('id')
      .eq('store_id', storeId)
      .eq('is_active', true)
      .ilike('name', normalizedName);

    if (dupError) {
      throw dupError;
    }

    if ((dupList ?? []).some((row) => row.id !== params.companyId)) {
      return NextResponse.json({ error: 'Tên nhà cung cấp đã tồn tại trong cửa hàng' }, { status: 409 });
    }

    const updateData = {
      ...payload,
      name: normalizedName,
    };

    delete (updateData as Record<string, unknown>).store_id;

    const { data, error } = await supabaseServer
      .from('companies')
      .update(updateData)
      .eq('id', params.companyId)
      .eq('store_id', storeId)
      .select()
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return NextResponse.json({ error: 'Nhà cung cấp không tồn tại' }, { status: 404 });
    }

    return NextResponse.json(data);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi cập nhật nhà cung cấp: ${message}` }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;

  try {
    const { data: products, error: productsError } = await supabaseServer
      .from('products')
      .select('id')
      .eq('company_id', params.companyId)
      .eq('store_id', storeId)
      .eq('is_active', true)
      .limit(1);

    if (productsError) {
      throw productsError;
    }

    if ((products ?? []).length > 0) {
      return NextResponse.json({ error: 'Không thể xóa nhà cung cấp vì còn sản phẩm đang sử dụng' }, { status: 400 });
    }

    const { error } = await supabaseServer
      .from('companies')
      .update({ is_active: false })
      .eq('id', params.companyId)
      .eq('store_id', storeId);

    if (error) {
      throw error;
    }

    return NextResponse.json({ success: true });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi xóa nhà cung cấp: ${message}` }, { status: 500 });
  }
}
