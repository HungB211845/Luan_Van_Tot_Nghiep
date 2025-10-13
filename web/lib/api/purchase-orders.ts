import { getAuthHeaders } from './utils';

type CreatePurchaseOrderPayload = {
  supplierId: string;
  items: Array<{
    productId: string;
    quantity: number;
    price: number;
  }>;
};

export const purchaseOrderService = {
  create: async (payload: CreatePurchaseOrderPayload) => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/create_purchase_order', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to create purchase order');
    }

    return response.json();
  },
};
