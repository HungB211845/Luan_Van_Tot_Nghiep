import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

type AdjustmentPayload = {
  batchId: string;
  quantityChange: number;
  reason: string;
  adjustmentType?: string;
  notes?: string | null;
};

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

    const payload = (await req.json().catch(() => null)) as AdjustmentPayload | null;

    if (!payload || typeof payload !== 'object') {
      return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
    }

    if (!payload.batchId || typeof payload.quantityChange !== 'number' || !payload.reason?.trim()) {
      return NextResponse.json({ error: 'batchId, quantityChange, and reason are required' }, { status: 400 });
    }

    const adjustmentData = {
      batch_id: payload.batchId,
      quantity_change: payload.quantityChange,
      reason: payload.reason,
      adjustment_type: payload.adjustmentType ?? 'manual',
      user_id_who_adjusted: user.id,
      notes: payload.notes ?? null,
      store_id: storeId,
    };

    const { data, error } = await supabaseServer
      .from('inventory_adjustments')
      .insert(adjustmentData)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json(data, { status: 201 });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi tạo điều chỉnh tồn kho: ${message}` }, { status: 500 });
  }
}
