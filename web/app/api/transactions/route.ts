import { createClient } from '@supabase/supabase-js';
import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Missing Supabase environment variables. Ensure NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY are set.',
  );
}

function createUserSupabaseClient(token: string) {
  return createClient(supabaseUrl!, supabaseAnonKey!, {
    global: {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
  });
}

function generateInvoiceNumber() {
  const now = new Date();
  const date =
    now.getFullYear().toString() +
    String(now.getMonth() + 1).padStart(2, '0') +
    String(now.getDate()).padStart(2, '0');
  const time =
    String(now.getHours()).padStart(2, '0') +
    String(now.getMinutes()).padStart(2, '0') +
    String(now.getSeconds()).padStart(2, '0') +
    String(now.getMilliseconds()).padStart(3, '0');
  return `INV${date}${time}`;
}

function parseNumericParam(value: string | null, fallback: number, min = 0, max?: number) {
  if (value == null) {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  const clamped = Math.max(parsed, min);
  if (typeof max === 'number') {
    return Math.min(clamped, max);
  }

  return clamped;
}

function toNullableString(value: unknown) {
  if (typeof value === 'string' && value.trim().length > 0) {
    return value.trim();
  }
  return null;
}

type RawTransactionItem = Record<string, unknown>;

function sanitizeTransactionItems(items: RawTransactionItem[], storeId: string) {
  const sanitized = items.map((item) => {
    const productId = toNullableString(
      item.productId ?? item.product_id ?? item['product-id'] ?? item['productId'],
    );
    const batchId = toNullableString(item.batchId ?? item.batch_id);
    const unitId = toNullableString(item.unitId ?? item.unit_id);
    const unitName = toNullableString(item.unitName ?? item.unit_name);

    const quantityValue = Number(
      item.quantity ?? item.qty ?? item.quantityRequested ?? item['quantity-requested'],
    );

    if (!productId) {
      throw new Error('Each transaction item must include productId');
    }

    if (!Number.isFinite(quantityValue) || quantityValue <= 0) {
      throw new Error(`Invalid quantity for product ${productId}`);
    }

    const priceValue = Number(
      item.priceAtSale ??
        item.price_at_sale ??
        item.unitPrice ??
        item.unit_price ??
        item.price ??
        item['unit-price'],
    );

    const subTotalValue = Number(
      item.subTotal ?? item.sub_total ?? (Number.isFinite(priceValue) ? priceValue * quantityValue : NaN),
    );

    if (!Number.isFinite(subTotalValue)) {
      throw new Error(`Invalid subtotal for product ${productId}`);
    }

    const discountValue = Number(item.discountAmount ?? item.discount_amount ?? 0);
    const baseUnitQuantityValue = Number(
      item.baseUnitQuantity ?? item.base_unit_quantity ?? item.baseQuantity ?? item.base_quantity ?? NaN,
    );
    const unitConversionFactor = Number(item.unitConversionFactor ?? item.unit_conversion_factor ?? NaN);

    const price = Number.isFinite(priceValue) ? priceValue : Number(subTotalValue / quantityValue);

    return {
      transaction_id: null as string | null,
      product_id: productId,
      batch_id: batchId,
      quantity: quantityValue,
      price_at_sale: price,
      sub_total: subTotalValue,
      discount_amount: Number.isFinite(discountValue) ? discountValue : 0,
      unit_id: unitId,
      unit_name: unitName,
      unit_conversion_factor: Number.isFinite(unitConversionFactor) ? unitConversionFactor : null,
      base_unit_quantity: Number.isFinite(baseUnitQuantityValue) ? baseUnitQuantityValue : quantityValue,
      store_id: storeId,
    };
  });

  return sanitized;
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
    const limit = parseNumericParam(searchParams.get('limit'), 50, 1, 200);
    const offset = parseNumericParam(searchParams.get('offset'), 0, 0);
    const to = offset + limit - 1;

    const isDebtParam = searchParams.get('isDebt');
    const customerId = toNullableString(searchParams.get('customerId'));
    const paymentMethod = toNullableString(searchParams.get('paymentMethod'));
    const startDate = toNullableString(searchParams.get('startDate'));
    const endDate = toNullableString(searchParams.get('endDate'));

    const includeItems = searchParams.get('includeItems') === 'true';
    const selectColumns = includeItems
      ? `
        id, store_id, customer_id, total_amount, surcharge_amount, transaction_date,
        is_debt, payment_method, notes, invoice_number, created_by, created_at,
        customers(name),
        transaction_items(
          id, product_id, batch_id, quantity, price_at_sale, sub_total, discount_amount,
          unit_id, unit_name, unit_conversion_factor, base_unit_quantity, created_at,
          products(name, sku)
        )
      `
      : `
        id, store_id, customer_id, total_amount, surcharge_amount, transaction_date,
        is_debt, payment_method, notes, invoice_number, created_by, created_at,
        customers(name)
      `;

    const baseQuery = supabaseServer
      .from('transactions')
      .select(selectColumns, { count: 'exact' })
      .eq('store_id', storeId)
      .order('transaction_date', { ascending: false })
      .range(offset, to)
      .modify((builder) => {
        if (isDebtParam === 'true') {
          builder.eq('is_debt', true);
        } else if (isDebtParam === 'false') {
          builder.eq('is_debt', false);
        }

        if (customerId) {
          builder.eq('customer_id', customerId);
        }

        if (paymentMethod) {
          builder.eq('payment_method', paymentMethod);
        }

        if (startDate) {
          builder.gte('transaction_date', startDate);
        }

        if (endDate) {
          builder.lte('transaction_date', endDate);
        }
      });

    const { data, error, count } = await baseQuery;

    if (error) {
      throw error;
    }

    const total = typeof count === 'number' ? count : data?.length ?? 0;
    const hasNextPage = total > offset + limit;

    return NextResponse.json({
      items: data ?? [],
      totalCount: total,
      offset,
      limit,
      hasNextPage,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi lấy danh sách giao dịch: ${message}` }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  const authHeader = req.headers.get('authorization');
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return NextResponse.json({ error: 'Authentication required' }, { status: 401 });
  }

  const userSupabase = createUserSupabaseClient(token);

  let transactionId: string | null = null;

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

    const itemsInput = Array.isArray((payload as Record<string, unknown>).items)
      ? ((payload as { items: RawTransactionItem[] }).items)
      : [];

    if (itemsInput.length === 0) {
      return NextResponse.json({ error: 'Danh sách sản phẩm không được bỏ trống' }, { status: 400 });
    }

    let sanitizedItems: ReturnType<typeof sanitizeTransactionItems>;

    try {
      sanitizedItems = sanitizeTransactionItems(itemsInput, storeId);
    } catch (itemError: unknown) {
      const message = itemError instanceof Error ? itemError.message : 'Invalid transaction items';
      return NextResponse.json({ error: message }, { status: 400 });
    }

    const paymentMethodRaw =
      (payload as Record<string, unknown>).paymentMethod ??
      (payload as Record<string, unknown>).payment_method;
    const paymentMethod =
      typeof paymentMethodRaw === 'string' ? paymentMethodRaw.trim().toUpperCase() : null;

    if (!paymentMethod) {
      return NextResponse.json({ error: 'Payment method is required' }, { status: 400 });
    }

    const surchargeAmountRaw =
      (payload as Record<string, unknown>).surchargeAmount ??
      (payload as Record<string, unknown>).surcharge_amount ??
      0;
    const surchargeAmount = Number(surchargeAmountRaw);
    if (!Number.isFinite(surchargeAmount) || surchargeAmount < 0) {
      return NextResponse.json({ error: 'Invalid surcharge amount' }, { status: 400 });
    }

    const transactionDateRaw =
      (payload as Record<string, unknown>).transactionDate ??
      (payload as Record<string, unknown>).transaction_date ??
      null;

    const transactionDate = transactionDateRaw
      ? new Date(transactionDateRaw as string).toISOString()
      : new Date().toISOString();

    const customerId = toNullableString(
      (payload as Record<string, unknown>).customerId ??
        (payload as Record<string, unknown>).customer_id,
    );

    const notes = toNullableString((payload as Record<string, unknown>).notes);
    const invoiceNumber =
      toNullableString(
        (payload as Record<string, unknown>).invoiceNumber ??
          (payload as Record<string, unknown>).invoice_number,
      ) ?? generateInvoiceNumber();

    const baseAmount = sanitizedItems.reduce(
      (sum, item) => sum + Number(item.sub_total ?? 0),
      0,
    );
    const totalAmount = baseAmount + surchargeAmount;

    const transactionRecord = {
      customer_id: customerId,
      total_amount: totalAmount,
      surcharge_amount: surchargeAmount,
      payment_method: paymentMethod,
      is_debt: paymentMethod === 'DEBT',
      notes,
      invoice_number: invoiceNumber,
      transaction_date: transactionDate,
      store_id: storeId,
    };

    const { data: insertedTransaction, error: insertTransactionError } = await supabaseServer
      .from('transactions')
      .insert(transactionRecord)
      .select()
      .single();

    if (insertTransactionError) {
      throw insertTransactionError;
    }

    transactionId = insertedTransaction.id as string;

    const itemsToInsert = sanitizedItems.map((item) => ({
      ...item,
      transaction_id: transactionId,
    }));

    const { error: insertItemsError } = await supabaseServer
      .from('transaction_items')
      .insert(itemsToInsert);

    if (insertItemsError) {
      throw insertItemsError;
    }

    const inventoryPayload = sanitizedItems.map((item) => ({
      product_id: item.product_id,
      quantity: item.quantity,
      base_unit_quantity:
        typeof item.base_unit_quantity === 'number' && Number.isFinite(item.base_unit_quantity)
          ? item.base_unit_quantity
          : item.quantity,
    }));

    const {
      data: inventoryResult,
      error: inventoryError,
    } = await userSupabase.rpc('update_inventory_fifo_batch', {
      items_json: inventoryPayload,
    });

    if (inventoryError) {
      throw inventoryError;
    }

    if (!inventoryResult || typeof inventoryResult !== 'object' || inventoryResult.success !== true) {
      const errorMessage =
        (inventoryResult as Record<string, unknown>)?.error ??
        'Lỗi cập nhật tồn kho sau khi tạo giao dịch';
      throw new Error(String(errorMessage));
    }

    const insufficientStock = (inventoryResult as Record<string, unknown>).insufficient_stock;
    if (Array.isArray(insufficientStock) && insufficientStock.length > 0) {
      const shortage = insufficientStock
        .map((item: Record<string, unknown>) => {
          const productId = item.product_id ?? item['product-id'] ?? 'unknown';
          const shortageValue = item.shortage ?? 0;
          return `${productId} thiếu ${shortageValue}`;
        })
        .join(', ');
      throw new Error(`Không đủ hàng tồn kho cho: ${shortage}`);
    }

    let debtId: string | null = null;
    if (paymentMethod === 'DEBT' && customerId) {
      const debtDueDateRaw =
        (payload as Record<string, unknown>).debtDueDate ??
        (payload as Record<string, unknown>).debt_due_date ??
        null;

      try {
        const {
          data: debtResponse,
          error: debtError,
        } = await userSupabase.rpc('create_credit_sale', {
          p_store_id: storeId,
          p_customer_id: customerId,
          p_transaction_id: transactionId,
          p_amount: totalAmount,
          p_due_date: debtDueDateRaw,
          p_notes: notes,
        });

        if (debtError) {
          throw debtError;
        }

        if (typeof debtResponse === 'string') {
          debtId = debtResponse;
        } else if (debtResponse && typeof debtResponse === 'object' && 'debtId' in debtResponse) {
          debtId = (debtResponse as Record<string, unknown>).debtId as string;
        }
      } catch (debtError) {
        console.error('Failed to create debt from transaction:', debtError);
      }
    }

    const { data: transactionWithDetails, error: fetchError } = await supabaseServer
      .from('transactions')
      .select(
        `
        id, store_id, customer_id, total_amount, surcharge_amount, transaction_date,
        is_debt, payment_method, notes, invoice_number, created_by, created_at,
        customers(name),
        transaction_items(
          id, product_id, batch_id, quantity, price_at_sale, sub_total, discount_amount,
          unit_id, unit_name, unit_conversion_factor, base_unit_quantity, created_at,
          products(name, sku)
        )
      `,
      )
      .eq('store_id', storeId)
      .eq('id', transactionId)
      .maybeSingle();

    if (fetchError) {
      throw fetchError;
    }

    return NextResponse.json(
      {
        transaction: transactionWithDetails ?? insertedTransaction,
        debtId,
      },
      { status: 201 },
    );
  } catch (error: unknown) {
    if (transactionId) {
      await supabaseServer.from('transaction_items').delete().eq('transaction_id', transactionId);
      await supabaseServer.from('transactions').delete().eq('id', transactionId);
    }

    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: `Lỗi tạo giao dịch: ${message}` }, { status: 500 });
  }
}
