import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

function parseMonths(value: string | null): number | null {
  if (!value?.trim()) {
    return null;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return null;
  }
  return Math.min(parsed, 12);
}

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
    const months = parseMonths(searchParams.get('months'));

    if (months !== null) {
      try {
        const { data, error } = await supabaseServer.rpc('get_expiring_batches_report', {
          p_months: months,
        });

        if (error) {
          throw error;
        }

        return NextResponse.json({ items: data ?? [] });
      } catch (rpcError) {
        console.warn('RPC get_expiring_batches_report failed, falling back:', rpcError);
      }
    }

    try {
      const { data, error } = await supabaseServer
        .from('expiring_batches')
        .select('*')
        .eq('store_id', storeId)
        .order('days_until_expiry', { ascending: true });

      if (!error && data) {
        return NextResponse.json({ items: data });
      }
    } catch (viewError) {
      console.warn('View expiring_batches unavailable, using manual fallback:', viewError);
    }

    const effectiveMonths = months ?? 1;
    const futureDate = new Date();
    futureDate.setMonth(futureDate.getMonth() + effectiveMonths);
    const futureDateStr = futureDate.toISOString().split('T')[0];

    const { data, error } = await supabaseServer
      .from('product_batches')
      .select('id, product_id, batch_number, quantity, expiry_date, products(name, sku)')
      .eq('store_id', storeId)
      .eq('is_available', true)
      .not('expiry_date', 'is', null)
      .lte('expiry_date', futureDateStr)
      .order('expiry_date', { ascending: true });

    if (error) {
      throw error;
    }

    const items =
      data?.map((batch) => {
        const expiryDate = batch.expiry_date ? new Date(batch.expiry_date) : null;
        const daysUntilExpiry = expiryDate
          ? Math.ceil((expiryDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
          : null;

        return {
          id: batch.id,
          product_id: batch.product_id,
          batch_number: batch.batch_number,
          quantity: batch.quantity,
          expiry_date: batch.expiry_date,
          days_until_expiry: daysUntilExpiry,
          product_name: batch.products?.name ?? null,
          product_sku: batch.products?.sku ?? null,
        };
      }) ?? [];

    return NextResponse.json({ items });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

