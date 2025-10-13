export type DebtStatus =
  | 'pending'
  | 'overdue'
  | 'paid'
  | 'cancelled';

export type Debt = {
  id: string;
  customer_id: string;
  store_id: string;
  amount: number;
  outstanding_amount: number;
  status: DebtStatus;
  due_date?: string | null;
  notes?: string | null;
  transaction_id?: string | null;
  created_at: string;
  updated_at: string;
};

export type DebtPayment = {
  id: string;
  debt_id: string;
  customer_id: string;
  store_id: string;
  payment_date: string;
  payment_amount: number;
  payment_method: string;
  notes?: string | null;
  created_at: string;
};

export type DebtAdjustment = {
  id: string;
  debt_id: string;
  store_id: string;
  amount: number;
  adjustment_type: string;
  reason: string;
  created_at: string;
};

export type DebtSummary = {
  total: number;
  outstanding: number;
  overdue: number;
};

