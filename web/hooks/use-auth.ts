import { useEffect, useState } from 'react';
import { supabaseClient } from '@/lib/supabase/client';
import { UserProfile } from '@/types/user';

type UseAuthState = {
  user: UserProfile | null;
  loading: boolean;
};

/**
 * Đồng bộ trạng thái đăng nhập từ Supabase cho phía frontend.
 */
export function useAuth(): UseAuthState {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      const {
        data: { user: supabaseUser },
      } = await supabaseClient.auth.getUser();

      if (supabaseUser) {
        const metadata = (supabaseUser.user_metadata ?? {}) as Record<string, unknown>;
        const storeId =
          typeof metadata.store_id === 'string' || typeof metadata.store_id === 'number'
            ? String(metadata.store_id)
            : undefined;

        setUser({
          id: supabaseUser.id,
          email: supabaseUser.email ?? '',
          storeId,
        });
      } else {
        setUser(null);
      }
      setLoading(false);
    };

    void load();

    const {
      data: { subscription },
    } = supabaseClient.auth.onAuthStateChange(async () => {
      await load();
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  return { user, loading };
}
