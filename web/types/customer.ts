export type Customer = {
  id: string;
  name: string;
  phone?: string | null;
  address?: string | null;
  email?: string | null;
  debt_limit?: number;
  notes?: string | null;
  store_id: string;
  created_at: string;
  updated_at: string;
};

