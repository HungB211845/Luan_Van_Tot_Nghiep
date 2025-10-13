import { Product } from './product';

export type PurchaseOrderStatus =
  | 'draft'
  | 'submitted'
  | 'approved'
  | 'partial_received'
  | 'received'
  | 'cancelled';

export type PurchaseOrder = {
  id: string;
  supplier_id: string;
  supplier_name?: string | null;
  po_number?: string | null;
  order_date: string;
  expected_delivery_date?: string | null;
  delivery_date?: string | null;
  status: PurchaseOrderStatus;
  subtotal: number;
  tax_amount: number;
  total_amount: number;
  discount_amount: number;
  payment_terms?: string | null;
  notes?: string | null;
  created_by?: string | null;
  store_id: string;
  created_at: string;
  updated_at: string;
};

export type PurchaseOrderItem = {
  id: string;
  purchase_order_id: string;
  product_id: string;
  quantity: number;
  unit_cost: number;
  selling_price?: number;
  unit?: string | null;
  total_cost: number;
  received_quantity: number;
  notes?: string | null;
  store_id: string;
  created_at: string;
  product_name?: string | null;
};

export type PurchaseOrderDetail = {
  order: PurchaseOrder;
  items: PurchaseOrderItem[];
};

export type PurchaseOrderWithProducts = {
  po: PurchaseOrder;
  products: Product[];
};
