import { supabaseClient } from '@/lib/supabase/client';

export async function getAuthHeaders() {
  const {
    data: { session },
    error,
  } = await supabaseClient.auth.getSession();

  if (error) {
    throw error;
  }

  if (!session) {
    throw new Error('User not logged in. Vui lòng đăng nhập trước khi truy cập dữ liệu được bảo vệ.');
  }

  return {
    Authorization: `Bearer ${session.access_token}`,
    'Content-Type': 'application/json',
  };
}
