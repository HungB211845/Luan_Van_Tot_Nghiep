import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type InventoryAnalyticsRequest = {
  lowStockThreshold?: number;
  expiringSoonDays?: number;
  slowMovingDays?: number;
};

function sanitizeNumber(value: unknown) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return undefined;
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

    const payload = (await req.json().catch(() => ({}))) as InventoryAnalyticsRequest;
    const lowStockThreshold = sanitizeNumber(payload?.lowStockThreshold);
    const expiringSoonDays = sanitizeNumber(payload?.expiringSoonDays);
    const slowMovingDays = sanitizeNumber(payload?.slowMovingDays);

    const [summaryResponse, alertsResponse] = await Promise.all([
      supabaseServer.rpc('get_inventory_summary'),
      supabaseServer.rpc('get_inventory_alerts', {
        ...(typeof lowStockThreshold === 'number' ? { p_low_stock_threshold: lowStockThreshold } : {}),
        ...(typeof expiringSoonDays === 'number' ? { p_expiring_soon_days: expiringSoonDays } : {}),
        ...(typeof slowMovingDays === 'number' ? { p_slow_moving_days: slowMovingDays } : {}),
      }),
    ]);

    if (!Array.isArray(summaryResponse) || summaryResponse.length === 0) {
      return NextResponse.json(
        { error: 'Không có dữ liệu tồn kho cho cửa hàng này.' },
        { status: 404 },
      );
    }

    if (
      !alertsResponse ||
      typeof alertsResponse !== 'object' ||
      Array.isArray(alertsResponse) ||
      alertsResponse === null
    ) {
      throw new Error('Invalid inventory alerts response');
    }

    const summary = summaryResponse[0] as Record<string, unknown>;
    const alerts = alertsResponse as Record<string, unknown>;

    const lowStockProducts = Array.isArray(alerts.low_stock_products)
      ? alerts.low_stock_products
      : [];
    const expiringSoonProducts = Array.isArray(alerts.expiring_soon_products)
      ? alerts.expiring_soon_products
      : [];
    const slowMovingProducts = Array.isArray(alerts.slow_moving_products)
      ? alerts.slow_moving_products
      : [];

    return NextResponse.json({
      summary: {
        total_inventory_value: Number(summary.total_inventory_value ?? 0),
        total_selling_value: Number(summary.total_selling_value ?? 0),
        potential_profit: Number(summary.potential_profit ?? 0),
        profit_margin: Number(summary.profit_margin ?? 0),
        total_items: Number(summary.total_items ?? 0),
        total_batches: Number(summary.total_batches ?? 0),
        low_stock_items: lowStockProducts.length,
        expiring_soon_items: expiringSoonProducts.length,
        slow_moving_items: slowMovingProducts.length,
      },
      alerts: {
        low_stock_products: lowStockProducts,
        expiring_soon_products: expiringSoonProducts,
        slow_moving_products: slowMovingProducts,
      },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy phân tích tồn kho: ${message}` }, { status: 500 });
  }
}

