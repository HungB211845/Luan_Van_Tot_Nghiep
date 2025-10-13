import { getAuthHeaders } from '@/lib/api/utils';
import {
  PurchaseOrder,
  PurchaseOrderDetail,
  PurchaseOrderStatus,
  PurchaseOrderWithProducts,
} from '@/types/purchase-order';

export type CreatePurchaseOrderPayload = {
  order: Record<string, unknown>;
  items: Record<string, unknown>[];
};

export const purchaseOrderService = {
  getAll: async (): Promise<PurchaseOrder[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/purchase-orders', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách đơn nhập hàng');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  search: async (params: {
    searchText?: string;
    supplierIds?: string[];
    sortBy?: string;
    sortAsc?: boolean;
  }): Promise<PurchaseOrder[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/search_purchase_orders', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        p_search_text: params.searchText,
        p_supplier_ids: params.supplierIds,
        p_sort_by: params.sortBy,
        p_sort_asc: params.sortAsc,
      }),
    });

    if (response.ok) {
      const payload = await response.json();
      return Array.isArray(payload) ? (payload as PurchaseOrder[]) : [];
    }

    // Fallback giống Flutter: trả danh sách tổng nếu RPC lỗi
    return purchaseOrderService.getAll();
  },

  getById: async (poId: string): Promise<PurchaseOrderDetail> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/purchase-orders/${encodeURIComponent(poId)}`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy chi tiết đơn nhập hàng');
    }

    return response.json();
  },

  create: async (payload: CreatePurchaseOrderPayload): Promise<PurchaseOrder> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/purchase-orders', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tạo đơn nhập hàng');
    }

    return response.json();
  },

  updateStatus: async (poId: string, status: PurchaseOrderStatus): Promise<PurchaseOrder> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/purchase-orders/${encodeURIComponent(poId)}/status`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ status }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi cập nhật trạng thái đơn nhập hàng');
    }

    return response.json();
  },

  receive: async (poId: string): Promise<PurchaseOrderWithProducts> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/purchase-orders/${encodeURIComponent(poId)}/receive`, {
      method: 'POST',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi khi nhận hàng cho đơn nhập');
    }

    return response.json();
  },

  getBatchesFromPO: async (poId: string): Promise<Record<string, unknown>[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/purchase-orders/${encodeURIComponent(poId)}/batches`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy lô hàng từ đơn nhập');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },
};
