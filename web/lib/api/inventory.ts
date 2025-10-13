import { getAuthHeaders } from '@/lib/api/utils';

export type InventoryAdjustmentPayload = {
  batchId: string;
  quantityChange: number;
  reason: string;
  adjustmentType?: string;
  notes?: string | null;
};

export type InventoryAdjustment = {
  id: string;
  batch_id: string;
  quantity_change: number;
  reason: string;
  adjustment_type: string;
  created_at: string;
  user_id_who_adjusted?: string | null;
  store_id: string;
  notes?: string | null;
};

export const inventoryService = {
  createAdjustment: async (payload: InventoryAdjustmentPayload): Promise<InventoryAdjustment> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/inventory/adjustments', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tạo điều chỉnh tồn kho');
    }

    return response.json();
  },

  voidBatch: async (batchId: string, reason: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/inventory/batches/${encodeURIComponent(batchId)}/void`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ reason }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi hủy lô hàng');
    }
  },

  getBatchPermissions: async (
    batchId: string,
  ): Promise<{ canEdit: boolean; canDelete: boolean }> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/inventory/batches/${encodeURIComponent(batchId)}/permissions`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi kiểm tra quyền lô hàng');
    }

    return response.json();
  },

  getBatchAdjustmentHistory: async (batchId: string): Promise<InventoryAdjustment[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/inventory/batches/${encodeURIComponent(batchId)}/history`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tải lịch sử điều chỉnh');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  getProductAdjustmentHistory: async (productId: string): Promise<InventoryAdjustment[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(
      `/api/inventory/products/${encodeURIComponent(productId)}/adjustments`,
      { headers },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tải lịch sử điều chỉnh sản phẩm');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  incrementBatchSalesCount: async (batchId: string, increment = 1): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/increment_batch_sales_count', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        batch_id: batchId,
        increment_by: increment,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi cập nhật số lần bán của lô hàng');
    }
  },
};

