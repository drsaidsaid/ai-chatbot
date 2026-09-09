-- WhatsApp CRM foundation schema
-- Phase 1 creates the shared contact layer plus the core WhatsApp tables.

CREATE OR REPLACE FUNCTION public.is_whatsapp_crm_staff()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin', 'manager', 'operator')
  );
$$;

CREATE TABLE IF NOT EXISTS public.crm_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text,
  phone text NOT NULL,
  phone_normalized text NOT NULL,
  email text,
  avatar_url text,
  company text,
  source_type text NOT NULL DEFAULT 'manual'
    CHECK (source_type IN ('lead', 'student', 'lead_and_student', 'manual')),
  assigned_user_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  lead_status text,
  student_status text,
  product_name text,
  label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_activity_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_crm_contacts_phone_normalized
  ON public.crm_contacts(phone_normalized);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_assigned_user_id
  ON public.crm_contacts(assigned_user_id);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_source_type
  ON public.crm_contacts(source_type);

CREATE TABLE IF NOT EXISTS public.crm_contact_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.crm_contacts(id) ON DELETE CASCADE,
  source_table text NOT NULL CHECK (source_table IN ('form_submissions', 'students')),
  source_id uuid NOT NULL,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT crm_contact_links_unique_source UNIQUE (source_table, source_id),
  CONSTRAINT crm_contact_links_unique_pair UNIQUE (contact_id, source_table, source_id)
);

CREATE INDEX IF NOT EXISTS idx_crm_contact_links_contact_id
  ON public.crm_contact_links(contact_id);

CREATE TABLE IF NOT EXISTS public.crm_contact_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.crm_contacts(id) ON DELETE CASCADE,
  tag text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT crm_contact_tags_unique UNIQUE (contact_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_crm_contact_tags_contact_id
  ON public.crm_contact_tags(contact_id);

CREATE TABLE IF NOT EXISTS public.crm_contact_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.crm_contacts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  note_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_contact_notes_contact_id
  ON public.crm_contact_notes(contact_id);

CREATE TABLE IF NOT EXISTS public.wa_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number_id text NOT NULL,
  waba_id text,
  access_token_encrypted text NOT NULL,
  verify_token_encrypted text,
  status text NOT NULL DEFAULT 'disconnected'
    CHECK (status IN ('connected', 'disconnected')),
  connected_at timestamptz,
  created_by uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_wa_config_phone_number_id
  ON public.wa_config(phone_number_id);

CREATE TABLE IF NOT EXISTS public.wa_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.crm_contacts(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'pending', 'closed')),
  assigned_user_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  last_message_text text,
  last_message_at timestamptz,
  unread_count integer NOT NULL DEFAULT 0,
  last_inbound_at timestamptz,
  last_outbound_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wa_conversations_contact_id
  ON public.wa_conversations(contact_id);
CREATE INDEX IF NOT EXISTS idx_wa_conversations_assigned_user_id
  ON public.wa_conversations(assigned_user_id);
CREATE INDEX IF NOT EXISTS idx_wa_conversations_last_message_at
  ON public.wa_conversations(last_message_at DESC);

CREATE TABLE IF NOT EXISTS public.wa_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.wa_conversations(id) ON DELETE CASCADE,
  sender_type text NOT NULL CHECK (sender_type IN ('customer', 'agent', 'bot')),
  sender_user_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  content_type text NOT NULL DEFAULT 'text'
    CHECK (content_type IN ('text', 'image', 'document', 'audio', 'video', 'location', 'template', 'reaction')),
  content_text text,
  media_url text,
  template_name text,
  meta_message_id text,
  reply_to_message_id uuid REFERENCES public.wa_messages(id) ON DELETE SET NULL,
  meta_parent_message_id text,
  status text NOT NULL DEFAULT 'sent'
    CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed')),
  error_message text,
  raw_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wa_messages_conversation_created_at
  ON public.wa_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_wa_messages_meta_message_id
  ON public.wa_messages(meta_message_id);

CREATE TABLE IF NOT EXISTS public.wa_message_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text,
  language text NOT NULL DEFAULT 'en_US',
  header_type text,
  header_content text,
  body_text text NOT NULL,
  footer_text text,
  buttons jsonb,
  status text,
  meta_template_id text,
  created_by uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wa_message_templates_name
  ON public.wa_message_templates(name);

CREATE TABLE IF NOT EXISTS public.wa_broadcasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  template_name text NOT NULL,
  template_language text NOT NULL DEFAULT 'en_US',
  template_variables jsonb,
  audience_filter jsonb,
  scheduled_at timestamptz,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'scheduled', 'sending', 'sent', 'failed')),
  total_recipients integer NOT NULL DEFAULT 0,
  sent_count integer NOT NULL DEFAULT 0,
  delivered_count integer NOT NULL DEFAULT 0,
  read_count integer NOT NULL DEFAULT 0,
  replied_count integer NOT NULL DEFAULT 0,
  failed_count integer NOT NULL DEFAULT 0,
  created_by uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wa_broadcasts_status
  ON public.wa_broadcasts(status);

CREATE TABLE IF NOT EXISTS public.wa_broadcast_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id uuid NOT NULL REFERENCES public.wa_broadcasts(id) ON DELETE CASCADE,
  contact_id uuid REFERENCES public.crm_contacts(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'delivered', 'read', 'replied', 'failed')),
  meta_message_id text,
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  replied_at timestamptz,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wa_broadcast_recipients_broadcast_id
  ON public.wa_broadcast_recipients(broadcast_id);

CREATE TABLE IF NOT EXISTS public.wa_pipelines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wa_pipeline_stages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.wa_pipelines(id) ON DELETE CASCADE,
  name text NOT NULL,
  position integer NOT NULL DEFAULT 0,
  color text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wa_pipeline_stages_pipeline_id
  ON public.wa_pipeline_stages(pipeline_id, position);

CREATE TABLE IF NOT EXISTS public.wa_deals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.wa_pipelines(id) ON DELETE CASCADE,
  stage_id uuid REFERENCES public.wa_pipeline_stages(id) ON DELETE SET NULL,
  contact_id uuid REFERENCES public.crm_contacts(id) ON DELETE SET NULL,
  conversation_id uuid REFERENCES public.wa_conversations(id) ON DELETE SET NULL,
  title text NOT NULL,
  value numeric(12,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TZS',
  notes text,
  expected_close_date date,
  status text NOT NULL DEFAULT 'active',
  assigned_user_id uuid REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wa_deals_pipeline_id
  ON public.wa_deals(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_wa_deals_stage_id
  ON public.wa_deals(stage_id);

ALTER TABLE public.crm_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_contact_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_contact_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_contact_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_broadcast_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_pipelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_pipeline_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_deals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "WhatsApp CRM staff manage contacts" ON public.crm_contacts;
CREATE POLICY "WhatsApp CRM staff manage contacts"
  ON public.crm_contacts
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage contact links" ON public.crm_contact_links;
CREATE POLICY "WhatsApp CRM staff manage contact links"
  ON public.crm_contact_links
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage contact tags" ON public.crm_contact_tags;
CREATE POLICY "WhatsApp CRM staff manage contact tags"
  ON public.crm_contact_tags
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage contact notes" ON public.crm_contact_notes;
CREATE POLICY "WhatsApp CRM staff manage contact notes"
  ON public.crm_contact_notes
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage config" ON public.wa_config;
CREATE POLICY "WhatsApp CRM staff manage config"
  ON public.wa_config
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage conversations" ON public.wa_conversations;
CREATE POLICY "WhatsApp CRM staff manage conversations"
  ON public.wa_conversations
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage messages" ON public.wa_messages;
CREATE POLICY "WhatsApp CRM staff manage messages"
  ON public.wa_messages
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage templates" ON public.wa_message_templates;
CREATE POLICY "WhatsApp CRM staff manage templates"
  ON public.wa_message_templates
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage broadcasts" ON public.wa_broadcasts;
CREATE POLICY "WhatsApp CRM staff manage broadcasts"
  ON public.wa_broadcasts
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage broadcast recipients" ON public.wa_broadcast_recipients;
CREATE POLICY "WhatsApp CRM staff manage broadcast recipients"
  ON public.wa_broadcast_recipients
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage pipelines" ON public.wa_pipelines;
CREATE POLICY "WhatsApp CRM staff manage pipelines"
  ON public.wa_pipelines
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage pipeline stages" ON public.wa_pipeline_stages;
CREATE POLICY "WhatsApp CRM staff manage pipeline stages"
  ON public.wa_pipeline_stages
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

DROP POLICY IF EXISTS "WhatsApp CRM staff manage deals" ON public.wa_deals;
CREATE POLICY "WhatsApp CRM staff manage deals"
  ON public.wa_deals
  FOR ALL
  USING (public.is_whatsapp_crm_staff())
  WITH CHECK (public.is_whatsapp_crm_staff());

CREATE OR REPLACE FUNCTION public.set_whatsapp_crm_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_crm_contacts_updated_at ON public.crm_contacts;
CREATE TRIGGER set_crm_contacts_updated_at
  BEFORE UPDATE ON public.crm_contacts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_whatsapp_crm_updated_at();

DROP TRIGGER IF EXISTS set_wa_config_updated_at ON public.wa_config;
CREATE TRIGGER set_wa_config_updated_at
  BEFORE UPDATE ON public.wa_config
  FOR EACH ROW
  EXECUTE FUNCTION public.set_whatsapp_crm_updated_at();

DROP TRIGGER IF EXISTS set_wa_conversations_updated_at ON public.wa_conversations;
CREATE TRIGGER set_wa_conversations_updated_at
  BEFORE UPDATE ON public.wa_conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.set_whatsapp_crm_updated_at();

DROP TRIGGER IF EXISTS set_wa_message_templates_updated_at ON public.wa_message_templates;
CREATE TRIGGER set_wa_message_templates_updated_at
  BEFORE UPDATE ON public.wa_message_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.set_whatsapp_crm_updated_at();

DROP TRIGGER IF EXISTS set_wa_broadcasts_updated_at ON public.wa_broadcasts;
CREATE TRIGGER set_wa_broadcasts_updated_at
  BEFORE UPDATE ON public.wa_broadcasts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_whatsapp_crm_updated_at();

DROP TRIGGER IF EXISTS set_wa_deals_updated_at ON public.wa_deals;
CREATE TRIGGER set_wa_deals_updated_at
  BEFORE UPDATE ON public.wa_deals
  FOR EACH ROW
  EXECUTE FUNCTION public.set_whatsapp_crm_updated_at();

-- Seed a default sales/admissions pipeline for first use.
INSERT INTO public.wa_pipelines (name)
SELECT 'Admissions Pipeline'
WHERE NOT EXISTS (
  SELECT 1 FROM public.wa_pipelines WHERE name = 'Admissions Pipeline'
);

WITH pipeline AS (
  SELECT id
  FROM public.wa_pipelines
  WHERE name = 'Admissions Pipeline'
  LIMIT 1
)
INSERT INTO public.wa_pipeline_stages (pipeline_id, name, position, color)
SELECT pipeline.id, seed.name, seed.position, seed.color
FROM pipeline
CROSS JOIN (
  VALUES
    ('New Inquiry', 0, '#2563eb'),
    ('Contacted', 1, '#0f766e'),
    ('Qualified', 2, '#7c3aed'),
    ('Follow-up', 3, '#d97706'),
    ('Sale Pending', 4, '#dc2626'),
    ('Sale Made', 5, '#16a34a'),
    ('Student Onboarding', 6, '#0891b2')
) AS seed(name, position, color)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.wa_pipeline_stages existing
  WHERE existing.pipeline_id = pipeline.id
    AND existing.name = seed.name
);
