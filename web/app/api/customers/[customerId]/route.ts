import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type RouteParams = {
  params: {
    customerId: string;
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

export async function GET(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;

  try {
    const { data, error } = await supabaseServer
      .from('customers')
      .select('*')
      .eq('id', params.customerId)
      .eq('store_id', storeId)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return NextResponse.json({ error: 'Khách hàng không tồn tại' }, { status: 404 });
    }

    return NextResponse.json(data);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy thông tin khách hàng: ${message}` }, { status: 500 });
  }
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

  try {
    const { data, error } = await supabaseServer
      .from('customers')
      .update(payload)
      .eq('id', params.customerId)
      .eq('store_id', storeId)
      .select()
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return NextResponse.json({ error: 'Khách hàng không tồn tại' }, { status: 404 });
    }

    return NextResponse.json(data);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi cập nhật khách hàng: ${message}` }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: RouteParams) {
  const auth = await authenticate(req);
  if ('error' in auth) {
    return auth.error;
  }

  const { storeId } = auth;

  try {
    const { error } = await supabaseServer
      .from('customers')
      .delete()
      .eq('id', params.customerId)
      .eq('store_id', storeId);

    if (error) {
      throw error;
    }

    return NextResponse.json({ success: true });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi xóa khách hàng: ${message}` }, { status: 500 });
  }
}
