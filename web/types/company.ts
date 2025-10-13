export type Company = {
  id: string;
  name: string;
  phone?: string | null;
  address?: string | null;
  contact_person?: string | null;
  note?: string | null;
  store_id: string;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
};
