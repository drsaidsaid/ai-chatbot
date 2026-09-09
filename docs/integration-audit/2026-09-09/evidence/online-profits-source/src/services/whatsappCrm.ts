import { supabase } from '@/lib/supabase';
import { extractLeadContactFields } from '@/lib/whatsapp/contactProjection';
import { normalizeWhatsAppPhone } from '@/lib/whatsapp/phone';

export interface WhatsAppCrmOverview {
    leadCount: number;
    studentCount: number;
    contactCount: number;
    conversationCount: number;
    migrationReady: boolean;
}

export interface WhatsAppBackfillReport {
    processed: number;
    created: number;
    updated: number;
    linked: number;
    skipped: number;
    invalidPhones: number;
    failures: number;
}

export interface WhatsAppCrmLink {
    source_table: 'form_submissions' | 'students';
    source_id: string;
    is_primary: boolean;
}

export interface WhatsAppCrmContact {
    id: string;
    full_name: string | null;
    phone: string;
    phone_normalized: string;
    email: string | null;
    source_type: 'lead' | 'student' | 'lead_and_student' | 'manual';
    assigned_user_id: string | null;
    lead_status: string | null;
    student_status: string | null;
    product_name: string | null;
    label: string | null;
    links?: WhatsAppCrmLink[];
}

export interface WhatsAppConversation {
    id: string;
    contact_id: string;
    status: 'open' | 'pending' | 'closed';
    assigned_user_id: string | null;
    last_message_text: string | null;
    last_message_at: string | null;
    unread_count: number;
    last_inbound_at: string | null;
    last_outbound_at: string | null;
    contact?: WhatsAppCrmContact;
}

export interface WhatsAppMessage {
    id: string;
    conversation_id: string;
    sender_type: 'customer' | 'agent' | 'bot';
    sender_user_id: string | null;
    content_type: 'text' | 'image' | 'document' | 'audio' | 'video' | 'location' | 'template' | 'reaction';
    content_text: string | null;
    media_url: string | null;
    template_name: string | null;
    status: 'sending' | 'sent' | 'delivered' | 'read' | 'failed';
    created_at: string;
}

export interface WhatsAppConfigView {
    id: string;
    phone_number_id: string;
    waba_id: string | null;
    status: 'connected' | 'disconnected';
    connected_at: string | null;
    created_at: string;
    updated_at: string;
    has_access_token: boolean;
    has_verify_token: boolean;
}

export interface SaveWhatsAppConfigInput {
    phoneNumberId: string;
    wabaId?: string;
    accessToken?: string;
    verifyToken?: string;
    status: 'connected' | 'disconnected';
}

const getCount = async (table: string) => {
    const { count, error } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true });

    if (error) throw error;
    return count || 0;
};

type ExistingContact = {
    id: string;
    full_name: string | null;
    phone: string;
    phone_normalized: string;
    email: string | null;
    source_type: 'lead' | 'student' | 'lead_and_student' | 'manual';
    assigned_user_id: string | null;
    lead_status: string | null;
    student_status: string | null;
    product_name: string | null;
    label: string | null;
    metadata: Record<string, unknown> | null;
};

type ContactMetadata = Record<string, unknown>;
type FormQuestion = {
    id: string;
    question?: string;
    fieldMapping?: string | null;
};

type FormRow = {
    id: string;
    slug: string | null;
    category: string | null;
    questions: FormQuestion[] | null;
};

type StudentContactRow = {
    id: string;
    full_name: string | null;
    email: string | null;
    phone: string | null;
    assigned_user_id: string | null;
    status: string | null;
    product_name: string | null;
    label: string | null;
    updated_at: string | null;
    enrolled_at: string | null;
};

type LeadSubmissionRow = {
    id: string;
    form_id: string;
    answers: Record<string, unknown>;
    submitted_at: string | null;
    crm_status: string | null;
    assigned_user_id: string | null;
    tracking_data: Record<string, unknown> | null;
};

type ContactWithLinksRow = WhatsAppCrmContact & {
    crm_contact_links?: WhatsAppCrmLink[];
};

type ContactProjection = {
    sourceTable: 'form_submissions' | 'students';
    sourceId: string;
    sourceType: 'lead' | 'student';
    fullName: string | null;
    phone: string;
    phoneNormalized: string;
    email: string | null;
    assignedUserId: string | null;
    leadStatus?: string | null;
    studentStatus?: string | null;
    productName?: string | null;
    label?: string | null;
    metadata?: ContactMetadata;
    isPrimary?: boolean;
    preferredTimestamp?: string | null;
};

const mergeSourceType = (
    current: ExistingContact['source_type'],
    incoming: ContactProjection['sourceType']
): ExistingContact['source_type'] => {
    if (current === 'lead_and_student') return current;
    if (current === incoming) return current;
    if ((current === 'lead' && incoming === 'student') || (current === 'student' && incoming === 'lead')) {
        return 'lead_and_student';
    }
    if (current === 'manual') return incoming;
    return current;
};

const chooseName = (existing: string | null, incoming: string | null, incomingType: ContactProjection['sourceType']) => {
    if (!incoming) return existing;
    if (!existing) return incoming;
    if (incomingType === 'student') return incoming;
    return existing;
};

const upsertLinkedContact = async (
    existingByPhone: Map<string, ExistingContact>,
    projection: ContactProjection
) => {
    const existing = existingByPhone.get(projection.phoneNormalized);
    let contactId: string;
    let created = 0;
    let updated = 0;

    if (existing) {
        const payload = {
            full_name: chooseName(existing.full_name, projection.fullName, projection.sourceType),
            phone: existing.phone || projection.phone,
            phone_normalized: projection.phoneNormalized,
            email: existing.email || projection.email,
            source_type: mergeSourceType(existing.source_type, projection.sourceType),
            assigned_user_id: projection.assignedUserId || existing.assigned_user_id,
            lead_status: projection.leadStatus ?? existing.lead_status,
            student_status: projection.studentStatus ?? existing.student_status,
            product_name: projection.productName ?? existing.product_name,
            label: projection.label ?? existing.label,
            metadata: {
                ...(existing.metadata || {}),
                ...(projection.metadata || {}),
            },
            last_activity_at: projection.preferredTimestamp || undefined,
        };

        const { data, error } = await supabase
            .from('crm_contacts')
            .update(payload)
            .eq('id', existing.id)
            .select('id, full_name, phone, phone_normalized, email, source_type, assigned_user_id, lead_status, student_status, product_name, label, metadata')
            .single();

        if (error) throw error;

        contactId = data.id;
        updated = 1;
        existingByPhone.set(projection.phoneNormalized, data as ExistingContact);
    } else {
        const payload = {
            full_name: projection.fullName,
            phone: projection.phone,
            phone_normalized: projection.phoneNormalized,
            email: projection.email,
            source_type: projection.sourceType,
            assigned_user_id: projection.assignedUserId,
            lead_status: projection.leadStatus ?? null,
            student_status: projection.studentStatus ?? null,
            product_name: projection.productName ?? null,
            label: projection.label ?? null,
            metadata: projection.metadata || {},
            last_activity_at: projection.preferredTimestamp || undefined,
        };

        const { data, error } = await supabase
            .from('crm_contacts')
            .insert(payload)
            .select('id, full_name, phone, phone_normalized, email, source_type, assigned_user_id, lead_status, student_status, product_name, label, metadata')
            .single();

        if (error) throw error;

        contactId = data.id;
        created = 1;
        existingByPhone.set(projection.phoneNormalized, data as ExistingContact);
    }

    const { error: linkError } = await supabase
        .from('crm_contact_links')
        .upsert({
            contact_id: contactId,
            source_table: projection.sourceTable,
            source_id: projection.sourceId,
            is_primary: projection.isPrimary ?? false,
        }, { onConflict: 'source_table,source_id' });

    if (linkError) throw linkError;

    return { contactId, created, updated };
};

export const WhatsAppCrmService = {
    async getOverview(): Promise<WhatsAppCrmOverview> {
        const [leadResult, studentResult, contactResult, conversationResult] = await Promise.allSettled([
            getCount('form_submissions'),
            getCount('students'),
            getCount('crm_contacts'),
            getCount('wa_conversations'),
        ]);

        const contactReady = contactResult.status === 'fulfilled';
        const conversationReady = conversationResult.status === 'fulfilled';

        return {
            leadCount: leadResult.status === 'fulfilled' ? leadResult.value : 0,
            studentCount: studentResult.status === 'fulfilled' ? studentResult.value : 0,
            contactCount: contactReady ? contactResult.value : 0,
            conversationCount: conversationReady ? conversationResult.value : 0,
            migrationReady: contactReady && conversationReady,
        };
    },

    async syncStudentContact(studentId: string) {
        const { data, error } = await supabase
            .from('students')
            .select('id, full_name, email, phone, assigned_user_id, status, product_name, label, updated_at, enrolled_at')
            .eq('id', studentId)
            .single();

        if (error) throw error;

        const phoneNormalized = normalizeWhatsAppPhone(data.phone);
        if (!phoneNormalized) return false;

        const existingContacts = await supabase
            .from('crm_contacts')
            .select('id, full_name, phone, phone_normalized, email, source_type, assigned_user_id, lead_status, student_status, product_name, label, metadata')
            .eq('phone_normalized', phoneNormalized)
            .maybeSingle();

        if (existingContacts.error) throw existingContacts.error;

        const existingByPhone = new Map<string, ExistingContact>();
        if (existingContacts.data) {
            existingByPhone.set(phoneNormalized, existingContacts.data as ExistingContact);
        }

        await upsertLinkedContact(existingByPhone, {
            sourceTable: 'students',
            sourceId: data.id,
            sourceType: 'student',
            fullName: data.full_name,
            phone: data.phone,
            phoneNormalized,
            email: data.email,
            assignedUserId: data.assigned_user_id,
            studentStatus: data.status,
            productName: data.product_name,
            label: data.label,
            metadata: {
                student_id: data.id,
                enrolled_at: data.enrolled_at,
            },
            isPrimary: true,
            preferredTimestamp: data.updated_at || data.enrolled_at,
        });

        return true;
    },

    async syncLeadContact(submissionId: string) {
        const [{ data: submission, error: submissionError }, { data: forms, error: formsError }] = await Promise.all([
            supabase
                .from('form_submissions')
                .select('id, form_id, answers, submitted_at, crm_status, assigned_user_id, tracking_data')
                .eq('id', submissionId)
                .single(),
            supabase
                .from('forms')
                .select('id, slug, category, questions')
                .limit(500),
        ]);

        if (submissionError) throw submissionError;
        if (formsError) throw formsError;

        const form = (forms as FormRow[] | null)?.find((entry) => entry.id === submission.form_id);
        if (form?.slug === 'sales-rep-application' || form?.category === 'Job Application') {
            return false;
        }

        const projection = extractLeadContactFields(submission.answers, form?.questions || []);
        if (!projection.phoneNormalized || !projection.phone) return false;

        const existingContacts = await supabase
            .from('crm_contacts')
            .select('id, full_name, phone, phone_normalized, email, source_type, assigned_user_id, lead_status, student_status, product_name, label, metadata')
            .eq('phone_normalized', projection.phoneNormalized)
            .maybeSingle();

        if (existingContacts.error) throw existingContacts.error;

        const existingByPhone = new Map<string, ExistingContact>();
        if (existingContacts.data) {
            existingByPhone.set(projection.phoneNormalized, existingContacts.data as ExistingContact);
        }

        await upsertLinkedContact(existingByPhone, {
            sourceTable: 'form_submissions',
            sourceId: submission.id,
            sourceType: 'lead',
            fullName: projection.fullName,
            phone: projection.phone,
            phoneNormalized: projection.phoneNormalized,
            email: projection.email,
            assignedUserId: submission.assigned_user_id,
            leadStatus: submission.crm_status,
            metadata: {
                form_id: submission.form_id,
                tracking_data: submission.tracking_data || {},
            },
            isPrimary: true,
            preferredTimestamp: submission.submitted_at,
        });

        return true;
    },

    async backfillContacts(): Promise<WhatsAppBackfillReport> {
        const report: WhatsAppBackfillReport = {
            processed: 0,
            created: 0,
            updated: 0,
            linked: 0,
            skipped: 0,
            invalidPhones: 0,
            failures: 0,
        };

        const [{ data: existingContacts, error: contactsError }, { data: forms, error: formsError }, { data: students, error: studentsError }, { data: submissions, error: submissionsError }] = await Promise.all([
            supabase
                .from('crm_contacts')
                .select('id, full_name, phone, phone_normalized, email, source_type, assigned_user_id, lead_status, student_status, product_name, label, metadata'),
            supabase
                .from('forms')
                .select('id, slug, category, questions')
                .limit(1000),
            supabase
                .from('students')
                .select('id, full_name, email, phone, assigned_user_id, status, product_name, label, updated_at, enrolled_at'),
            supabase
                .from('form_submissions')
                .select('id, form_id, answers, submitted_at, crm_status, assigned_user_id, tracking_data'),
        ]);

        if (contactsError) throw contactsError;
        if (formsError) throw formsError;
        if (studentsError) throw studentsError;
        if (submissionsError) throw submissionsError;

        const existingByPhone = new Map<string, ExistingContact>(
            ((existingContacts as ExistingContact[] | null) || []).map((contact) => [contact.phone_normalized, contact])
        );
        const formsById = new Map<string, FormRow>(((forms as FormRow[] | null) || []).map((form) => [form.id, form]));

        const processProjection = async (projection: ContactProjection | null) => {
            if (!projection) {
                report.skipped += 1;
                return;
            }

            report.processed += 1;

            try {
                const result = await upsertLinkedContact(existingByPhone, projection);
                report.created += result.created;
                report.updated += result.updated;
                report.linked += 1;
            } catch (error) {
                report.failures += 1;
                console.error('WhatsApp CRM backfill failure:', error);
            }
        };

        for (const student of (students as StudentContactRow[] | null) || []) {
            const phoneNormalized = normalizeWhatsAppPhone(student.phone);
            if (!phoneNormalized) {
                report.invalidPhones += 1;
                report.skipped += 1;
                continue;
            }

            await processProjection({
                sourceTable: 'students',
                sourceId: student.id,
                sourceType: 'student',
                fullName: student.full_name,
                phone: student.phone,
                phoneNormalized,
                email: student.email,
                assignedUserId: student.assigned_user_id,
                studentStatus: student.status,
                productName: student.product_name,
                label: student.label,
                metadata: {
                    student_id: student.id,
                    enrolled_at: student.enrolled_at,
                },
                isPrimary: true,
                preferredTimestamp: student.updated_at || student.enrolled_at,
            });
        }

        for (const submission of (submissions as LeadSubmissionRow[] | null) || []) {
            const form = formsById.get(submission.form_id);
            if (form?.slug === 'sales-rep-application' || form?.category === 'Job Application') {
                report.skipped += 1;
                continue;
            }

            const extracted = extractLeadContactFields(submission.answers, form?.questions || []);
            if (!extracted.phoneNormalized || !extracted.phone) {
                report.invalidPhones += 1;
                report.skipped += 1;
                continue;
            }

            await processProjection({
                sourceTable: 'form_submissions',
                sourceId: submission.id,
                sourceType: 'lead',
                fullName: extracted.fullName,
                phone: extracted.phone,
                phoneNormalized: extracted.phoneNormalized,
                email: extracted.email,
                assignedUserId: submission.assigned_user_id,
                leadStatus: submission.crm_status,
                metadata: {
                    form_id: submission.form_id,
                    tracking_data: submission.tracking_data || {},
                },
                isPrimary: true,
                preferredTimestamp: submission.submitted_at,
            });
        }

        return report;
    },

    async getContacts(searchQuery?: string): Promise<WhatsAppCrmContact[]> {
        let query = supabase
            .from('crm_contacts')
            .select('id, full_name, phone, phone_normalized, email, source_type, assigned_user_id, lead_status, student_status, product_name, label, crm_contact_links(source_table, source_id, is_primary)')
            .order('updated_at', { ascending: false })
            .limit(200);

        if (searchQuery?.trim()) {
            const search = searchQuery.trim();
            query = query.or(`full_name.ilike.%${search}%,phone.ilike.%${search}%,email.ilike.%${search}%`);
        }

        const { data, error } = await query;
        if (error) throw error;

        return ((data as ContactWithLinksRow[] | null) || []).map((row) => ({
            ...row,
            links: row.crm_contact_links || [],
        }));
    },

    async getConversations(): Promise<WhatsAppConversation[]> {
        const { data, error } = await supabase
            .from('wa_conversations')
            .select(`
                id,
                contact_id,
                status,
                assigned_user_id,
                last_message_text,
                last_message_at,
                unread_count,
                last_inbound_at,
                last_outbound_at,
                contact:crm_contacts(
                    id,
                    full_name,
                    phone,
                    phone_normalized,
                    email,
                    source_type,
                    assigned_user_id,
                    lead_status,
                    student_status,
                    product_name,
                    label
                )
            `)
            .order('last_message_at', { ascending: false, nullsFirst: false })
            .order('created_at', { ascending: false });

        if (error) throw error;
        return (data || []) as unknown as WhatsAppConversation[];
    },

    async getConversationMessages(conversationId: string): Promise<WhatsAppMessage[]> {
        const { data, error } = await supabase
            .from('wa_messages')
            .select('id, conversation_id, sender_type, sender_user_id, content_type, content_text, media_url, template_name, status, created_at')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: true });

        if (error) throw error;
        return (data || []) as WhatsAppMessage[];
    },

    async ensureConversation(contactId: string): Promise<string> {
        const { data: existing, error: existingError } = await supabase
            .from('wa_conversations')
            .select('id')
            .eq('contact_id', contactId)
            .order('updated_at', { ascending: false })
            .limit(1)
            .maybeSingle();

        if (existingError) throw existingError;
        if (existing?.id) return existing.id;

        const { data, error } = await supabase
            .from('wa_conversations')
            .insert({ contact_id: contactId, status: 'open', unread_count: 0 })
            .select('id')
            .single();

        if (error) throw error;
        return data.id;
    },

    async sendTextMessage(conversationId: string, message: string) {
        const { data, error } = await supabase.functions.invoke('whatsapp-send', {
            body: {
                conversationId,
                text: message,
            },
        });

        if (error) throw error;
        return data;
    },

    async getConfig(): Promise<WhatsAppConfigView | null> {
        const { data, error } = await supabase.functions.invoke('whatsapp-config', {
            body: { action: 'get' },
        });

        if (error) throw error;
        return data?.config || null;
    },

    async saveConfig(input: SaveWhatsAppConfigInput): Promise<WhatsAppConfigView> {
        const { data, error } = await supabase.functions.invoke('whatsapp-config', {
            body: {
                action: 'save',
                ...input,
            },
        });

        if (error) throw error;
        if (!data?.config) {
            throw new Error('WhatsApp config save did not return a config row.');
        }
        return data.config as WhatsAppConfigView;
    },
};
