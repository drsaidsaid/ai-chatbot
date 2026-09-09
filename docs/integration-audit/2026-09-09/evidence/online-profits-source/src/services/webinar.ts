import { supabase } from '@/lib/supabase';
import { getYouTubeVideoId } from '@/lib/webinar';
import type { Webinar, WebinarAttendanceRecord, WebinarAuditEvent, WebinarModerationMessage, WebinarRegistration, WebinarSaleCandidate, WebinarSession } from '@/types/webinar';

const mapSession = (row: Record<string, unknown>): WebinarSession => ({
  id: String(row.id), webinarId: String(row.webinar_id), title: String(row.title),
  scheduledStartAt: String(row.scheduled_start_at), expectedEndAt: row.expected_end_at as string | null,
  youtubeUrl: row.youtube_url as string | null, youtubeVideoId: row.youtube_video_id as string | null,
  status: row.status as WebinarSession['status'], sortOrder: Number(row.sort_order || 0),
  actualStartedAt: row.actual_started_at as string | null, actualEndedAt: row.actual_ended_at as string | null, chatEnabled: row.chat_enabled !== false,
});

type WebinarRow = Record<string, unknown> & { webinar_sessions?: Record<string, unknown>[]; counts?: Webinar['counts'] };

const mapWebinar = (row: WebinarRow): Webinar => ({
  id: String(row.id), title: String(row.title), slug: String(row.slug), shortDescription: row.short_description as string | null,
  description: row.description as string | null, hostName: row.host_name as string | null, hostImageUrl: row.host_image_url as string | null,
  heroImageUrl: row.hero_image_url as string | null, benefits: (row.benefits as string[] | undefined) || [], agenda: (row.agenda as string[] | undefined) || [], testimonials: (row.testimonials as unknown[] | undefined) || [],
  registrationMode: row.registration_mode as Webinar['registrationMode'], price: Number(row.price || 0), regularPrice: row.regular_price == null ? null : Number(row.regular_price), includedAccessEnabled: Boolean(row.included_access_enabled),
  targetCapacity: row.target_capacity as number | null, overbookingPercent: Number(row.overbooking_percent ?? 20),
  registrationCutoffAt: row.registration_cutoff_at as string | null, registrationCutoffOverridden: Boolean(row.registration_cutoff_overridden), status: row.status as Webinar['status'], productId: row.product_id as string | null, audienceId: row.audience_id as string | null,
  replayUrl: row.replay_url as string | null, replayPublishedAt: row.replay_published_at as string | null, replayExpiresAt: row.replay_expires_at as string | null, formId: row.form_id as string | null,
  sessions: (row.webinar_sessions || []).map(mapSession), counts: row.counts, effectiveCapacity: row.effective_capacity as number | null, registrationOpen: row.registration_open as boolean | undefined,
});

export const WebinarService = {
  async list(): Promise<Webinar[]> {
    const { data, error } = await supabase.from('webinars').select('*, webinar_sessions(*)').order('created_at', { ascending: false });
    if (error) throw error;
    return (data || []).map((row) => mapWebinar(row as WebinarRow));
  },
  async getBySlug(slug: string): Promise<Webinar | null> {
    const { data, error } = await supabase.rpc('get_public_webinar', { p_slug: slug });
    if (error) throw error;
    return data ? mapWebinar(data as WebinarRow) : null;
  },
  async getById(id: string): Promise<Webinar | null> {
    const { data, error } = await supabase.from('webinars').select('*, webinar_sessions(*)').eq('id', id).single();
    if (error) {
      if (error.code === 'PGRST116') return null;
      throw error;
    }
    return mapWebinar(data as WebinarRow);
  },
  async registrations(webinarId: string): Promise<WebinarRegistration[]> {
    const { data, error } = await supabase.from('webinar_registrations').select('*').eq('webinar_id', webinarId).order('created_at', { ascending: false });
    if (error) throw error;
    return (data || []).map((row: Record<string, unknown>) => ({
      id: String(row.id), webinarId: String(row.webinar_id), submissionId: row.submission_id as string | null, studentId: row.student_id as string | null, saleId: row.sale_id as string | null,
      fullName: String(row.full_name), email: String(row.email), phone: String(row.phone), marketingConsent: Boolean(row.marketing_consent),
      source: row.source as WebinarRegistration['source'], status: row.status as WebinarRegistration['status'], seatReserved: Boolean(row.seat_reserved), accessToken: row.access_token as string | null, createdAt: String(row.created_at),
    }));
  },
  async save(webinar: Partial<Webinar>): Promise<string> {
    const payload = {
      title: webinar.title, slug: webinar.slug, short_description: webinar.shortDescription || null, description: webinar.description || null,
      host_name: webinar.hostName || null, host_image_url: webinar.hostImageUrl || null, hero_image_url: webinar.heroImageUrl || null,
      benefits: webinar.benefits || [], agenda: webinar.agenda || [], testimonials: webinar.testimonials || [],
      registration_mode: webinar.registrationMode || 'free', price: webinar.price || 0, included_access_enabled: webinar.includedAccessEnabled || false,
      target_capacity: webinar.targetCapacity || null, overbooking_percent: webinar.overbookingPercent ?? 20, registration_cutoff_at: webinar.registrationCutoffAt || null, registration_cutoff_overridden: Boolean(webinar.registrationCutoffAt), status: webinar.status || 'draft',
    };
    const request = webinar.id ? supabase.from('webinars').update(payload).eq('id', webinar.id).select('id').single() : supabase.from('webinars').insert(payload).select('id').single();
    const { data, error } = await request;
    if (error) throw error;
    return data.id;
  },
  async updatePublishedContent(webinar: Partial<Webinar> & { id: string }): Promise<void> {
    const { error } = await supabase.rpc('update_published_webinar_content', {
      p_webinar_id: webinar.id,
      p_title: webinar.title || '',
      p_short_description: webinar.shortDescription || null,
      p_description: webinar.description || null,
      p_host_name: webinar.hostName || null,
      p_host_image_url: webinar.hostImageUrl || null,
      p_hero_image_url: webinar.heroImageUrl || null,
      p_benefits: webinar.benefits || [],
      p_agenda: webinar.agenda || [],
    });
    if (error) throw error;
  },
  async saveSession(session: Partial<WebinarSession>): Promise<void> {
    const payload = { webinar_id: session.webinarId, title: session.title, scheduled_start_at: session.scheduledStartAt, expected_end_at: session.expectedEndAt || null, youtube_url: session.youtubeUrl || null, youtube_video_id: session.youtubeUrl ? getYouTubeVideoId(session.youtubeUrl) : null, sort_order: session.sortOrder || 0 };
    if (session.id) {
      const { error } = await supabase.rpc('reschedule_webinar_session', { p_session_id: session.id, p_title: session.title, p_scheduled_start_at: session.scheduledStartAt, p_expected_end_at: session.expectedEndAt || null, p_youtube_url: session.youtubeUrl || null, p_youtube_video_id: payload.youtube_video_id });
      if (error) throw error;
      return;
    }
    const { error } = await supabase.rpc('add_webinar_session', { p_webinar_id: session.webinarId, p_title: session.title, p_scheduled_start_at: session.scheduledStartAt, p_expected_end_at: session.expectedEndAt || null, p_youtube_url: session.youtubeUrl || null, p_youtube_video_id: payload.youtube_video_id, p_sort_order: session.sortOrder || 0 });
    if (error) throw error;
  },
  async publish(webinarId: string): Promise<void> {
    const { error } = await supabase.rpc('publish_webinar', { p_webinar_id: webinarId });
    if (error) throw error;
  },
  async startSession(sessionId: string): Promise<void> {
    const { error } = await supabase.rpc('start_webinar_session', { p_session_id: sessionId });
    if (error) throw error;
  },
  async endSession(sessionId: string): Promise<void> {
    const { error } = await supabase.rpc('end_webinar_session', { p_session_id: sessionId });
    if (error) throw error;
  },
  async publishReplay(webinarId: string, replayUrl: string): Promise<void> {
    const { error } = await supabase.rpc('publish_webinar_replay', { p_webinar_id: webinarId, p_replay_url: replayUrl });
    if (error) throw error;
  },
  async extendReplay(webinarId: string, days: number): Promise<string> {
    const { data, error } = await supabase.rpc('extend_webinar_replay', { p_webinar_id: webinarId, p_days: days });
    if (error) throw error;
    return String(data);
  },
  async cancelSession(sessionId: string, reason?: string): Promise<void> {
    const { error } = await supabase.rpc('cancel_webinar_session', { p_session_id: sessionId, p_reason: reason || null });
    if (error) throw error;
  },
  async cancel(webinarId: string, reason?: string): Promise<void> {
    const { error } = await supabase.rpc('cancel_webinar', { p_webinar_id: webinarId, p_reason: reason || null });
    if (error) throw error;
  },
  async archive(webinarId: string): Promise<void> {
    const { error } = await supabase.rpc('archive_webinar', { p_webinar_id: webinarId });
    if (error) throw error;
  },
  async attendance(webinarId: string): Promise<WebinarAttendanceRecord[]> {
    const { data, error } = await supabase.rpc('get_webinar_attendance', { p_webinar_id: webinarId });
    if (error) throw error;
    return (data || []).map((row: Record<string, unknown>) => ({
      registrationId: String(row.registration_id), fullName: String(row.full_name), email: String(row.email), phone: String(row.phone), source: String(row.source), status: String(row.status),
      firstLiveJoinAt: row.first_live_join_at as string | null, lastLivePresenceAt: row.last_live_presence_at as string | null, livePresenceSeconds: Number(row.live_presence_seconds || 0), replayOpenedAt: row.replay_opened_at as string | null,
    }));
  },
  async overrideCapacity(webinarId: string, targetCapacity: number | null, overbookingPercent: number | null, reason: string): Promise<number | null> {
    const { data, error } = await supabase.rpc('override_webinar_capacity', { p_webinar_id: webinarId, p_target_capacity: targetCapacity, p_overbooking_percent: overbookingPercent, p_reason: reason || null });
    if (error) throw error;
    return data === null ? null : Number(data);
  },
  async reopenRegistration(webinarId: string, cutoffAt: string): Promise<void> {
    const { error } = await supabase.rpc('reopen_webinar_registration', { p_webinar_id: webinarId, p_registration_cutoff_at: cutoffAt });
    if (error) throw error;
  },
  async moderationMessages(sessionId: string): Promise<WebinarModerationMessage[]> {
    const { data, error } = await supabase.from('webinar_chat_messages').select('id, registration_id, author_name, body, created_at').eq('session_id', sessionId).is('deleted_at', null).order('created_at', { ascending: false }).limit(100);
    if (error) throw error;
    return (data || []).map((row: Record<string, unknown>) => ({ id: String(row.id), registrationId: row.registration_id as string | null, authorName: String(row.author_name), body: String(row.body), createdAt: String(row.created_at) }));
  },
  async moderateChat(messageId?: string | null, registrationId?: string | null, mutedUntil?: string | null, reason?: string | null): Promise<void> {
    const { error } = await supabase.rpc('moderate_webinar_chat', { p_message_id: messageId || null, p_registration_id: registrationId || null, p_muted_until: mutedUntil || null, p_reason: reason || null });
    if (error) throw error;
  },
  async setSessionChat(sessionId: string, enabled: boolean): Promise<void> {
    const { error } = await supabase.rpc('set_webinar_session_chat', { p_session_id: sessionId, p_enabled: enabled });
    if (error) throw error;
  },
  async auditEvents(webinarId: string): Promise<WebinarAuditEvent[]> {
    const { data, error } = await supabase.from('webinar_audit_events').select('id, action, metadata, created_at').eq('webinar_id', webinarId).order('created_at', { ascending: false }).limit(25);
    if (error) throw error;
    return (data || []).map((row: Record<string, unknown>) => ({ id: String(row.id), action: String(row.action), metadata: (row.metadata as Record<string, unknown>) || {}, createdAt: String(row.created_at) }));
  },
  async deliveryStatus(webinarId: string) {
    const { data, error } = await supabase.rpc('get_webinar_delivery_status', { p_webinar_id: webinarId });
    if (error) throw error;
    return (data || []) as Array<{ id: string; registration_id: string; kind: string; scheduled_for: string; completed_at: string | null; failed_at: string | null; attempts: number; last_error: string | null }>;
  },
  async retryEmail(jobId: string): Promise<void> {
    const { error } = await supabase.rpc('retry_webinar_email_job', { p_job_id: jobId });
    if (error) throw error;
  },
  async register(input: { webinarId: string; fullName: string; email: string; phone: string; marketingConsent: boolean; paymentMethod?: string | null }) {
    const { data, error } = await supabase.rpc('register_for_webinar', { p_webinar_id: input.webinarId, p_full_name: input.fullName, p_email: input.email, p_phone: input.phone, p_marketing_consent: input.marketingConsent, p_payment_method: input.paymentMethod || null });
    if (error) throw error;
    return data as { registration_id: string; status: WebinarRegistration['status']; payment_required: boolean };
  },
  async syncSale(registrationId: string, saleId: string) {
    const { data, error } = await supabase.rpc('sync_webinar_sale', { p_registration_id: registrationId, p_sale_id: saleId });
    if (error) throw error;
    return data as { status: WebinarRegistration['status'] };
  },
  async saleCandidates(registrationId: string): Promise<WebinarSaleCandidate[]> {
    const { data, error } = await supabase.rpc('get_webinar_sale_candidates', { p_registration_id: registrationId });
    if (error) throw error;
    return (data || []).map((row: Record<string, unknown>) => ({
      saleId: String(row.sale_id), approvalStatus: String(row.approval_status), amountPaid: Number(row.amount_paid || 0), totalAmount: Number(row.total_amount || 0), createdAt: String(row.created_at),
    }));
  },
  async resendAccess(registrationId: string): Promise<string> {
    const { data, error } = await supabase.rpc('resend_webinar_access', { p_registration_id: registrationId });
    if (error) throw error;
    return String(data);
  },
  async revokeAccess(registrationId: string, reason?: string) {
    const { error } = await supabase.rpc('revoke_webinar_access', { p_registration_id: registrationId, p_reason: reason || null });
    if (error) throw error;
  },
  async clearRoomSession(registrationId: string): Promise<void> {
    const { error } = await supabase.rpc('clear_webinar_room_session', { p_registration_id: registrationId });
    if (error) throw error;
  },
  async getRoom(token: string, deviceId: string) {
    const { data, error } = await supabase.rpc('open_webinar_room', { p_access_token: token, p_device_id: deviceId });
    if (error) throw error;
    return data as Record<string, unknown>;
  },
  async heartbeat(token: string, roomSessionId: string, sessionId?: string | null): Promise<void> {
    const { error } = await supabase.rpc('heartbeat_webinar_room', { p_access_token: token, p_room_session_id: roomSessionId, p_session_id: sessionId || null });
    if (error) throw error;
  },
  async chat(token: string, roomSessionId: string, sessionId: string) {
    const { data, error } = await supabase.rpc('get_webinar_chat', { p_access_token: token, p_room_session_id: roomSessionId, p_session_id: sessionId });
    if (error) throw error;
    return (data || []) as Array<{ id: string; author_name: string; body: string; created_at: string }>;
  },
  async postChat(token: string, roomSessionId: string, sessionId: string, body: string): Promise<void> {
    const { error } = await supabase.rpc('post_webinar_chat_message', { p_access_token: token, p_room_session_id: roomSessionId, p_session_id: sessionId, p_body: body.trim() });
    if (error) throw error;
  },
};
