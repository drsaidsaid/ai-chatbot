import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const WHATSAPP_CONFIG_SECRET = Deno.env.get("WHATSAPP_CONFIG_SECRET");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });

const normalizePhone = (value: string) => value.replace(/\D/g, "");

const deriveKey = async () => {
  const secretBytes = new TextEncoder().encode(WHATSAPP_CONFIG_SECRET!);
  const hash = await crypto.subtle.digest("SHA-256", secretBytes);
  return crypto.subtle.importKey("raw", hash, "AES-GCM", false, ["decrypt"]);
};

const decrypt = async (value: string) => {
  const [ivBase64, cipherBase64] = value.split(":");
  if (!ivBase64 || !cipherBase64) throw new Error("Malformed encrypted token.");
  const iv = Uint8Array.from(atob(ivBase64), (char) => char.charCodeAt(0));
  const cipher = Uint8Array.from(atob(cipherBase64), (char) => char.charCodeAt(0));
  const key = await deriveKey();
  const plainBuffer = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, cipher);
  return new TextDecoder().decode(plainBuffer);
};

const getAuthorizedContext = async (req: Request) => {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY || !WHATSAPP_CONFIG_SECRET) {
    throw new Error("WhatsApp send function environment is incomplete.");
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new Error("Missing Authorization header.");

  const token = authHeader.replace("Bearer ", "");
  const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error,
  } = await authClient.auth.getUser(token);

  if (error || !user) throw new Error("Unauthorized");

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: profile, error: profileError } = await adminClient
    .from("user_profiles")
    .select("id, role")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) throw new Error("Unable to resolve user profile.");
  if (!["admin", "super_admin", "manager", "operator"].includes(profile.role)) {
    throw new Error("Forbidden");
  }

  return { user, adminClient };
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const conversationId = String(body.conversationId || "").trim();
    const text = String(body.text || "").trim();

    if (!conversationId || !text) {
        return json({ error: "conversationId and text are required." }, 400);
    }

    const { user, adminClient } = await getAuthorizedContext(req);

    const { data: config, error: configError } = await adminClient
      .from("wa_config")
      .select("*")
      .eq("status", "connected")
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (configError) throw configError;
    if (!config?.access_token_encrypted || !config?.phone_number_id) {
      return json({ error: "WhatsApp is not configured." }, 400);
    }

    const { data: conversation, error: conversationError } = await adminClient
      .from("wa_conversations")
      .select(`
        id,
        contact:crm_contacts(
          id,
          phone
        )
      `)
      .eq("id", conversationId)
      .single();

    if (conversationError || !conversation?.contact?.phone) {
      return json({ error: "Conversation or contact phone not found." }, 404);
    }

    const accessToken = await decrypt(config.access_token_encrypted);
    const to = normalizePhone(conversation.contact.phone);
    if (!to) {
      return json({ error: "Contact phone is invalid." }, 400);
    }

    const metaResponse = await fetch(
      `https://graph.facebook.com/v21.0/${config.phone_number_id}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to,
          type: "text",
          text: { body: text },
        }),
      }
    );

    const metaPayload = await metaResponse.json();
    if (!metaResponse.ok) {
      return json({ error: metaPayload?.error?.message || "Meta API request failed." }, 400);
    }

    const metaMessageId = metaPayload?.messages?.[0]?.id || null;

    const { data: message, error: messageError } = await adminClient
      .from("wa_messages")
      .insert({
        conversation_id: conversationId,
        sender_type: "agent",
        sender_user_id: user.id,
        content_type: "text",
        content_text: text,
        meta_message_id: metaMessageId,
        status: "sent",
      })
      .select("id, created_at")
      .single();

    if (messageError) throw messageError;

    const { error: conversationUpdateError } = await adminClient
      .from("wa_conversations")
      .update({
        last_message_text: text,
        last_message_at: message.created_at,
        last_outbound_at: message.created_at,
      })
      .eq("id", conversationId);

    if (conversationUpdateError) throw conversationUpdateError;

    return json({
      success: true,
      messageId: message.id,
      metaMessageId,
    });
  } catch (error: any) {
    const message = error?.message || "Unexpected error.";
    const status = message === "Unauthorized" ? 401 : message === "Forbidden" ? 403 : 500;
    return json({ error: message }, status);
  }
});
