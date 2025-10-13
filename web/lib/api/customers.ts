import { getAuthHeaders } from '@/lib/api/utils';
import { Customer } from '@/types/customer';

export type CustomerStatistics = {
  transaction_count: number;
  total_revenue: number;
  outstanding_debt: number;
};

export const customerService = {
  getAll: async (params?: { sortBy?: string; ascending?: boolean }): Promise<Customer[]> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams();

    if (params?.sortBy) {
      searchParams.set('sortBy', params.sortBy);
    }

    if (typeof params?.ascending === 'boolean') {
      searchParams.set('ascending', String(params.ascending));
    }

    const response = await fetch(`/api/customers${searchParams.toString() ? `?${searchParams}` : ''}`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách khách hàng');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  search: async (query: string): Promise<Customer[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/customers/search?q=${encodeURIComponent(query)}`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tìm kiếm khách hàng');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  create: async (customer: Partial<Customer>): Promise<Customer> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/customers', {
      method: 'POST',
      headers,
      body: JSON.stringify(customer),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tạo khách hàng mới');
    }

    return response.json();
  },

  update: async (customerId: string, customer: Partial<Customer>): Promise<Customer> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/customers/${encodeURIComponent(customerId)}`, {
      method: 'PUT',
      headers,
      body: JSON.stringify(customer),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi cập nhật khách hàng');
    }

    return response.json();
  },

  delete: async (customerId: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/customers/${encodeURIComponent(customerId)}`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi xóa khách hàng');
    }
  },

  getById: async (customerId: string): Promise<Customer | null> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/customers/${encodeURIComponent(customerId)}`, { headers });

    if (response.status === 404) {
      return null;
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy thông tin khách hàng');
    }

    return response.json();
  },

  getStatistics: async (customerId: string): Promise<CustomerStatistics> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/customers/statistics', {
      method: 'POST',
      headers,
      body: JSON.stringify({ customerId }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy thống kê khách hàng');
    }

    return response.json();
  },
};

