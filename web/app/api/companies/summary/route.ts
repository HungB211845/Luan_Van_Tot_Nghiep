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

    const { data: companies, error: companiesError } = await supabaseServer
      .from('companies')
      .select('*')
      .eq('store_id', storeId)
      .eq('is_active', true)
      .order('name', { ascending: true });

    if (companiesError) {
      throw companiesError;
    }

    const items: Array<Record<string, unknown>> = [];

    for (const company of companies ?? []) {
      const companyId = company.id as string;

      const [{ count: productsCount }, { count: ordersCount }] = await Promise.all([
        supabaseServer
          .from('products')
          .select('id', { count: 'exact', head: true })
          .eq('store_id', storeId)
          .eq('company_id', companyId)
          .eq('is_active', true),
        supabaseServer
          .from('purchase_orders')
          .select('id', { count: 'exact', head: true })
          .eq('store_id', storeId)
          .eq('supplier_id', companyId),
      ]);

      items.push({
        id: companyId,
        name: company.name,
        phone: company.phone,
        address: company.address,
        contact_person: company.contact_person,
        note: company.note,
        store_id: company.store_id,
        created_at: company.created_at,
        updated_at: company.updated_at,
        products_count: productsCount ?? 0,
        orders_count: ordersCount ?? 0,
      });
    }

    return NextResponse.json({ items });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy danh sách nhà cung cấp với metadata: ${message}` }, { status: 500 });
  }
}
