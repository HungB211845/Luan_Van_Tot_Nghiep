import { getAuthHeaders } from '@/lib/api/utils';
import { Company } from '@/types/company';
import { Product } from '@/types/product';

export const companyService = {
  getAll: async (): Promise<Company[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/companies', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách nhà cung cấp');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  create: async (company: Partial<Company>): Promise<Company> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/companies', {
      method: 'POST',
      headers,
      body: JSON.stringify(company),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tạo nhà cung cấp');
    }

    return response.json();
  },

  update: async (companyId: string, company: Partial<Company>): Promise<Company> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/companies/${encodeURIComponent(companyId)}`, {
      method: 'PUT',
      headers,
      body: JSON.stringify(company),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi cập nhật nhà cung cấp');
    }

    return response.json();
  },

  delete: async (companyId: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/companies/${encodeURIComponent(companyId)}`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi xóa nhà cung cấp');
    }
  },

  getProducts: async (companyId: string): Promise<Product[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/companies/${encodeURIComponent(companyId)}/products`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy sản phẩm của nhà cung cấp');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  existsName: async (name: string, excludeId?: string): Promise<boolean> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams({ name });
    if (excludeId) {
      searchParams.set('excludeId', excludeId);
    }

    const response = await fetch(`/api/companies/exists?${searchParams.toString()}`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi kiểm tra tên nhà cung cấp');
    }

    const payload = await response.json();
    return Boolean(payload.exists);
  },

  hasProducts: async (companyId: string): Promise<boolean> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/companies/${encodeURIComponent(companyId)}/has-products`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi kiểm tra sản phẩm của nhà cung cấp');
    }

    const payload = await response.json();
    return Boolean(payload.hasProducts);
  },

  hasPurchaseOrders: async (companyId: string): Promise<boolean> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/companies/${encodeURIComponent(companyId)}/has-purchase-orders`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi kiểm tra đơn nhập hàng của nhà cung cấp');
    }

    const payload = await response.json();
    return Boolean(payload.hasPurchaseOrders);
  },

  getSummary: async (): Promise<Array<Record<string, unknown>>> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/companies/summary', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách nhà cung cấp với metadata');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },
};

