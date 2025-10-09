-- Store invitation system for multi-tenant staff management
-- Allows store owners to invite staff members via email

BEGIN;

-- Store invitations table
CREATE TABLE IF NOT EXISTS public.store_invitations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    email text NOT NULL,
    full_name text NOT NULL,
    phone text,
    role text NOT NULL CHECK (role IN ('MANAGER', 'CASHIER', 'INVENTORY_STAFF')),
    permissions jsonb DEFAULT '{}',
    invited_at timestamptz DEFAULT now(),
    invited_by uuid REFERENCES auth.users(id),
    expires_at timestamptz NOT NULL,
    is_accepted boolean DEFAULT false,
    accepted_at timestamptz,
    accepted_by uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_store_invitations_store_id ON public.store_invitations (store_id);
CREATE INDEX IF NOT EXISTS idx_store_invitations_email ON public.store_invitations (email);
CREATE INDEX IF NOT EXISTS idx_store_invitations_expires_at ON public.store_invitations (expires_at);

-- RLS Policies
ALTER TABLE public.store_invitations ENABLE ROW LEVEL SECURITY;

-- Store owners/managers can see invitations for their store
DROP POLICY IF EXISTS store_invitations_select_own ON public.store_invitations;
CREATE POLICY store_invitations_select_own
ON public.store_invitations FOR SELECT
TO authenticated
USING (
    store_id IN (
        SELECT up.store_id
        FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('OWNER', 'MANAGER')
        AND up.is_active = true
    )
);

-- Store owners/managers can create invitations for their store
DROP POLICY IF EXISTS store_invitations_insert_own ON public.store_invitations;
CREATE POLICY store_invitations_insert_own
ON public.store_invitations FOR INSERT
TO authenticated
WITH CHECK (
    store_id IN (
        SELECT up.store_id
        FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('OWNER', 'MANAGER')
        AND up.is_active = true
    )
);

-- Store owners/managers can update invitations for their store
DROP POLICY IF EXISTS store_invitations_update_own ON public.store_invitations;
CREATE POLICY store_invitations_update_own
ON public.store_invitations FOR UPDATE
TO authenticated
USING (
    store_id IN (
        SELECT up.store_id
        FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('OWNER', 'MANAGER')
        AND up.is_active = true
    )
)
WITH CHECK (
    store_id IN (
        SELECT up.store_id
        FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.role IN ('OWNER', 'MANAGER')
        AND up.is_active = true
    )
);

-- Public read access for accepting invitations (before user is assigned to store)
DROP POLICY IF EXISTS store_invitations_public_accept ON public.store_invitations;
CREATE POLICY store_invitations_public_accept
ON public.store_invitations FOR SELECT
TO authenticated
USING (
    email = (auth.jwt() ->> 'email')
    AND is_accepted = false
    AND expires_at > now()
);

-- Function to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for store_invitations
DROP TRIGGER IF EXISTS update_store_invitations_updated_at ON public.store_invitations;
CREATE TRIGGER update_store_invitations_updated_at
    BEFORE UPDATE ON public.store_invitations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;