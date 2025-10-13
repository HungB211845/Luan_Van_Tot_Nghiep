import { getAuthHeaders } from '@/lib/api/utils';
import { Debt, DebtAdjustment, DebtPayment } from '@/types/debt';

export type CreateDebtFromTransactionPayload = {
  transactionId: string;
  amount: number;
  customerId?: string;
  dueDate?: string;
  notes?: string;
};

export type CreateManualDebtPayload = {
  customerId: string;
  amount: number;
  notes?: string;
};

export type AddPaymentPayload = {
  customerId: string;
  amount: number;
  paymentMethod?: string;
  notes?: string;
};

export type AdjustDebtPayload = {
  amount: number;
  type: 'increase' | 'decrease' | 'write_off';
  reason: string;
};

export type DebtStatistics = {
  transaction_count: number;
  total_revenue: number;
  outstanding_debt: number;
};

export const debtService = {
  createFromTransaction: async (payload: CreateDebtFromTransactionPayload): Promise<string> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/debts/from-transaction', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tạo công nợ từ giao dịch');
    }

    const data = await response.json();
    return data.debtId as string;
  },

  createManual: async (payload: CreateManualDebtPayload): Promise<string> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/debts/manual', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi ghi nợ thủ công');
    }

    const data = await response.json();
    return data.debtId as string;
  },

  getCustomerDebts: async (customerId: string): Promise<Debt[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/customers/${encodeURIComponent(customerId)}/debts`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách nợ');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  getAll: async (params?: { status?: string; onlyOverdue?: boolean }): Promise<Debt[]> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams();

    if (params?.status) {
      searchParams.set('status', params.status);
    }

    if (params?.onlyOverdue) {
      searchParams.set('onlyOverdue', 'true');
    }

    const response = await fetch(`/api/debts${searchParams.toString() ? `?${searchParams}` : ''}`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách nợ');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  addPayment: async (payload: AddPaymentPayload): Promise<Record<string, unknown>> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/debts/payments', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi xử lý thanh toán');
    }

    return response.json();
  },

  getDebtPayments: async (debtId: string): Promise<DebtPayment[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/debts/${encodeURIComponent(debtId)}/payments`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy lịch sử thanh toán');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  getCustomerPayments: async (customerId: string): Promise<DebtPayment[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/customers/${encodeURIComponent(customerId)}/payments`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy lịch sử thanh toán');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  adjustDebt: async (debtId: string, payload: AdjustDebtPayload): Promise<Record<string, unknown>> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/debts/${encodeURIComponent(debtId)}/adjustments`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi điều chỉnh công nợ');
    }

    return response.json();
  },

  getDebtAdjustments: async (debtId: string): Promise<DebtAdjustment[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/debts/${encodeURIComponent(debtId)}/adjustments`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy lịch sử điều chỉnh');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  calculateOverdueInterest: async (debtId: string, dailyRate = 0.001): Promise<number> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/calculate_overdue_interest', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        p_debt_id: debtId,
        p_daily_interest_rate: dailyRate,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tính lãi quá hạn');
    }

    const payload = await response.json();
    return typeof payload === 'number' ? payload : Number(payload ?? 0);
  },

  getById: async (debtId: string): Promise<Debt | null> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/debts/${encodeURIComponent(debtId)}`, {
      headers,
    });

    if (response.status === 404) {
      return null;
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy thông tin công nợ');
    }

    return response.json();
  },

  cancelDebt: async (debtId: string, reason: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/debts/${encodeURIComponent(debtId)}/cancel`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ reason }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi hủy công nợ');
    }
  },
};

