<script setup>
/* eslint-disable vue/no-bare-strings-in-template */
import { computed, onMounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import whatsappTemplatesAPI from 'dashboard/api/whatsappTemplates';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const templates = ref([]);
const resubmittableStatuses = ['draft', 'submission_failed'];
const saving = ref(false);
const loading = ref(false);
const editingTemplateId = ref(null);
const variableExamples = ref({});
const form = ref({
  inbox_id: '',
  name: '',
  language: 'en_US',
  category: 'UTILITY',
  body: '',
  media_type: '',
  media_handle: '',
  button_type: '',
  button_text: '',
  button_url: '',
  button_phone_number: '',
  estimate_amount: '',
  estimate_currency: '',
  estimate_market: '',
  estimate_effective_on: '',
  estimate_source: '',
  estimate_confirmed: false,
});
const inboxes = computed(() =>
  store.getters['inboxes/getInboxes'].filter(
    inbox => inbox.channel_type === 'Channel::Whatsapp'
  )
);
const variablePositions = computed(() => [
  ...new Set(
    [...form.value.body.matchAll(/\{\{\s*(\d+)\s*\}\}/g)].map(match =>
      Number(match[1])
    )
  ),
]);
const previewBody = computed(() =>
  form.value.body.replace(/\{\{\s*(\d+)\s*\}\}/g, (placeholder, position) =>
    variableExamples.value[position]?.trim()
      ? variableExamples.value[position]
      : placeholder
  )
);

const load = async () => {
  loading.value = true;
  try {
    await store.dispatch('inboxes/get');
    const { data } = await whatsappTemplatesAPI.get();
    templates.value = data;
  } finally {
    loading.value = false;
  }
};

const resetForm = inboxId => {
  form.value = {
    inbox_id: inboxId || '',
    name: '',
    language: 'en_US',
    category: 'UTILITY',
    body: '',
    media_type: '',
    media_handle: '',
    button_type: '',
    button_text: '',
    button_url: '',
    button_phone_number: '',
    estimate_amount: '',
    estimate_currency: '',
    estimate_market: '',
    estimate_effective_on: '',
    estimate_source: '',
    estimate_confirmed: false,
  };
  editingTemplateId.value = null;
  variableExamples.value = {};
};

const draftPayload = () => {
  const variables = variablePositions.value.map(position => ({
    position,
    example: variableExamples.value[position]?.trim() || '',
  }));
  const media =
    form.value.media_type && form.value.media_handle
      ? {
          format: form.value.media_type,
          example: { header_handle: [form.value.media_handle] },
        }
      : {};
  const button = form.value.button_type
    ? {
        type: form.value.button_type,
        text: form.value.button_text,
        ...(form.value.button_type === 'URL'
          ? { url: form.value.button_url }
          : {}),
        ...(form.value.button_type === 'PHONE_NUMBER'
          ? { phone_number: form.value.button_phone_number }
          : {}),
      }
    : null;
  const hasEstimate = [
    form.value.estimate_amount,
    form.value.estimate_currency,
    form.value.estimate_market,
    form.value.estimate_effective_on,
    form.value.estimate_source,
  ].some(Boolean);

  return {
    inbox_id: form.value.inbox_id,
    name: form.value.name,
    language: form.value.language,
    category: form.value.category,
    body: form.value.body,
    variables,
    media,
    buttons: button ? [button] : [],
    ...(hasEstimate
      ? {
          meta_charge_estimate: {
            amount: form.value.estimate_amount,
            currency: form.value.estimate_currency,
            market: form.value.estimate_market,
            effective_on: form.value.estimate_effective_on,
            source: form.value.estimate_source,
            confirmed: form.value.estimate_confirmed,
          },
        }
      : {}),
  };
};

const save = async () => {
  saving.value = true;
  try {
    const payload = draftPayload();
    const editedTemplateId = editingTemplateId.value;
    const { data } = editedTemplateId
      ? await whatsappTemplatesAPI.update(editedTemplateId, payload)
      : await whatsappTemplatesAPI.create(payload);
    const existingIndex = templates.value.findIndex(
      item => item.id === data.id
    );
    if (existingIndex >= 0) templates.value.splice(existingIndex, 1, data);
    else templates.value.unshift(data);
    resetForm(form.value.inbox_id);
    useAlert(
      editedTemplateId
        ? 'New revision saved. Local validation is not Meta approval.'
        : 'Draft saved. Local validation is not Meta approval.'
    );
  } catch (error) {
    useAlert(
      error.response?.data?.error || 'Template draft could not be saved.'
    );
  } finally {
    saving.value = false;
  }
};

const submit = async record => {
  const { data } = await whatsappTemplatesAPI.submit(record.id);
  Object.assign(record, data);
  useAlert('Submitted for Meta review. No customer message was sent.');
};

const reconcile = async record => {
  await whatsappTemplatesAPI.reconcile(record.id);
  useAlert('Reconciliation requested; the template was not submitted again.');
};

const edit = record => {
  const preview = record.preview || {};
  const media = preview.media || {};
  const button = preview.buttons?.[0] || {};
  const estimate = record.meta_charge_estimate || {};
  editingTemplateId.value = record.id;
  form.value = {
    inbox_id: record.inbox_id,
    name: record.name,
    language: record.language,
    category: record.category,
    body: preview.body || '',
    media_type: media.format || '',
    media_handle: media.example?.header_handle?.[0] || '',
    button_type: button.type || '',
    button_text: button.text || '',
    button_url: button.url || '',
    button_phone_number: button.phone_number || '',
    estimate_amount: estimate.amount || '',
    estimate_currency: estimate.currency || '',
    estimate_market: estimate.market || '',
    estimate_effective_on: estimate.effective_on || '',
    estimate_source: estimate.source || '',
    estimate_confirmed: false,
  };
  variableExamples.value = Object.fromEntries(
    (preview.variables || []).map(variable => [
      variable.position,
      variable.example || '',
    ])
  );
};

onMounted(load);
</script>

<template>
  <main class="flex-1 min-w-0 bg-n-background p-4 sm:p-6">
    <section class="max-w-4xl mx-auto space-y-8">
      <header>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          WhatsApp templates
        </h1>
        <p class="mt-2 text-sm text-n-slate-11">
          Draft a Meta template, preview it as a recipient would, and track
          Meta’s decision. Meta billing is direct and separate from AI
          allowance.
        </p>
      </header>
      <form
        class="grid gap-4 rounded-lg border border-n-weak p-5"
        @submit.prevent="save"
      >
        <label class="text-sm font-medium text-n-slate-12"
          >WhatsApp inbox
          <select
            v-model="form.inbox_id"
            required
            :disabled="Boolean(editingTemplateId)"
            class="mt-1 w-full rounded border border-n-weak bg-n-solid-1 p-2"
          >
            <option value="" disabled>Select an inbox</option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </label>
        <div class="grid gap-4 sm:grid-cols-3">
          <label class="text-sm font-medium text-n-slate-12"
            >Name<input
              v-model.trim="form.name"
              required
              :disabled="Boolean(editingTemplateId)"
              pattern="[a-z0-9_]+"
              class="mt-1 w-full rounded border border-n-weak p-2" /></label
          ><label class="text-sm font-medium text-n-slate-12"
            >Language<input
              v-model.trim="form.language"
              required
              :disabled="Boolean(editingTemplateId)"
              data-testid="template-language"
              class="mt-1 w-full rounded border border-n-weak p-2" /></label
          ><label class="text-sm font-medium text-n-slate-12"
            >Category<select
              v-model="form.category"
              class="mt-1 w-full rounded border border-n-weak p-2"
            >
              <option>UTILITY</option>
              <option>MARKETING</option>
              <option>AUTHENTICATION</option>
            </select></label
          >
        </div>
        <label class="text-sm font-medium text-n-slate-12"
          >Template body<textarea
            v-model.trim="form.body"
            required
            maxlength="20000"
            rows="4"
            class="mt-1 w-full rounded border border-n-weak p-2"
          />
        </label>
        <div class="grid gap-4 sm:grid-cols-2">
          <label class="text-sm font-medium text-n-slate-12">
            Optional media header
            <select
              v-model="form.media_type"
              class="mt-1 w-full rounded border border-n-weak p-2"
            >
              <option value="">No media</option>
              <option value="IMAGE">Image</option>
              <option value="VIDEO">Video</option>
              <option value="DOCUMENT">Document</option>
            </select>
          </label>
          <label
            v-if="form.media_type"
            class="text-sm font-medium text-n-slate-12"
          >
            Meta sample media handle
            <input
              id="whatsapp-template-media-handle"
              v-model.trim="form.media_handle"
              required
              class="mt-1 w-full rounded border border-n-weak p-2"
            />
          </label>
        </div>
        <div class="grid gap-4 sm:grid-cols-3">
          <label class="text-sm font-medium text-n-slate-12">
            Optional button
            <select
              v-model="form.button_type"
              class="mt-1 w-full rounded border border-n-weak p-2"
            >
              <option value="">No button</option>
              <option value="QUICK_REPLY">Quick reply</option>
              <option value="URL">Website</option>
              <option value="PHONE_NUMBER">Phone number</option>
            </select>
          </label>
          <label
            v-if="form.button_type"
            class="text-sm font-medium text-n-slate-12"
          >
            Button text
            <input
              id="whatsapp-template-button-text"
              v-model.trim="form.button_text"
              required
              class="mt-1 w-full rounded border border-n-weak p-2"
            />
          </label>
          <label
            v-if="form.button_type === 'URL'"
            class="text-sm font-medium text-n-slate-12"
          >
            Button URL
            <input
              id="whatsapp-template-button-url"
              v-model.trim="form.button_url"
              required
              type="url"
              class="mt-1 w-full rounded border border-n-weak p-2"
            />
          </label>
          <label
            v-if="form.button_type === 'PHONE_NUMBER'"
            class="text-sm font-medium text-n-slate-12"
          >
            Phone number
            <input
              id="whatsapp-template-button-phone"
              v-model.trim="form.button_phone_number"
              required
              type="tel"
              class="mt-1 w-full rounded border border-n-weak p-2"
            />
          </label>
        </div>
        <div
          v-if="variablePositions.length"
          class="grid gap-3 rounded border border-n-weak p-4"
        >
          <p class="text-sm font-medium text-n-slate-12">
            Variable sample values
          </p>
          <label
            v-for="position in variablePositions"
            :key="position"
            class="text-sm text-n-slate-11"
          >
            Variable &#123;&#123;{{ position }}&#125;&#125;
            <input
              :id="`whatsapp-template-variable-${position}`"
              v-model.trim="variableExamples[position]"
              required
              class="mt-1 w-full rounded border border-n-weak p-2"
            />
          </label>
        </div>
        <aside class="rounded bg-n-solid-2 p-4 text-sm text-n-slate-12">
          <p class="font-medium">Recipient preview</p>
          <p v-if="form.media_type" class="mt-2 text-n-slate-11">
            {{
              `${form.media_type.charAt(0)}${form.media_type.slice(1).toLowerCase()} header`
            }}
            <span v-if="form.media_handle">· sample attached</span>
          </p>
          <p class="mt-2 whitespace-pre-wrap">
            {{ previewBody || 'Your template text will appear here.' }}
          </p>
          <p v-if="form.button_type" class="mt-3">
            <span class="inline-flex rounded border border-n-weak px-3 py-1">
              {{ form.button_text || 'Button preview' }}
            </span>
          </p>
          <p class="mt-2 text-n-slate-11">
            Use numbered variables such as &#123;&#123;1&#125;&#125;. They are
            checked before saving, but only Meta can approve a template.
          </p>
        </aside>
        <fieldset class="grid gap-3 rounded border border-n-weak p-4">
          <legend class="px-1 text-sm font-medium text-n-slate-12">
            Optional owner-verified Meta charge estimate
          </legend>
          <p class="text-sm text-n-slate-11">
            Enter a current Meta source; the product does not invent or assume a
            rate. Leave every field empty to keep the estimate unknown.
          </p>
          <div class="grid gap-3 sm:grid-cols-3">
            <label class="text-sm text-n-slate-11"
              >Amount<input
                v-model.trim="form.estimate_amount"
                data-testid="estimate-amount"
                inputmode="decimal"
                class="mt-1 w-full rounded border border-n-weak p-2"
            /></label>
            <label class="text-sm text-n-slate-11"
              >Currency<input
                v-model.trim="form.estimate_currency"
                data-testid="estimate-currency"
                maxlength="3"
                class="mt-1 w-full rounded border border-n-weak p-2 uppercase"
            /></label>
            <label class="text-sm text-n-slate-11"
              >Market<input
                v-model.trim="form.estimate_market"
                data-testid="estimate-market"
                class="mt-1 w-full rounded border border-n-weak p-2"
            /></label>
            <label class="text-sm text-n-slate-11"
              >Effective date<input
                v-model="form.estimate_effective_on"
                data-testid="estimate-effective-on"
                type="date"
                class="mt-1 w-full rounded border border-n-weak p-2"
            /></label>
            <label class="text-sm text-n-slate-11 sm:col-span-2"
              >Meta source or rate-card reference<input
                v-model.trim="form.estimate_source"
                data-testid="estimate-source"
                class="mt-1 w-full rounded border border-n-weak p-2"
            /></label>
          </div>
          <label class="flex items-start gap-2 text-sm text-n-slate-12">
            <input
              v-model="form.estimate_confirmed"
              data-testid="estimate-confirmed"
              type="checkbox"
              class="mt-1"
            />
            I verified this estimate against the named Meta source for this
            market and effective date.
          </label>
        </fieldset>
        <div class="flex flex-wrap gap-2">
          <Button type="submit" :is-loading="saving">
            {{ editingTemplateId ? 'Save new revision' : 'Save draft' }}
          </Button>
          <button
            v-if="editingTemplateId"
            type="button"
            class="rounded border border-n-weak px-3 py-2 text-sm"
            @click="resetForm(form.inbox_id)"
          >
            Cancel edit
          </button>
        </div>
      </form>
      <section>
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              Saved templates
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              Missing Meta pricing is shown as unknown, never as zero.
            </p>
          </div>
          <button
            type="button"
            data-testid="refresh-templates"
            class="rounded border border-n-weak px-3 py-2 text-sm"
            :disabled="loading"
            @click="load"
          >
            {{ loading ? 'Refreshing…' : 'Refresh templates' }}
          </button>
        </div>
        <div
          v-for="record in templates"
          :key="record.id"
          class="mt-3 rounded-lg border border-n-weak p-4 text-sm"
        >
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="font-medium text-n-slate-12">
                {{ record.name }} · {{ record.language }}
              </p>
              <p class="text-n-slate-11">
                Revision {{ record.revision }} · Meta status:
                {{ record.meta_approval }} ·
                {{ record.sendable ? 'Sendable' : 'Not sendable' }}
              </p>
              <p class="text-n-slate-11">
                Meta charge:
                {{
                  record.meta_charge_estimate
                    ? `${record.meta_charge_estimate.amount} ${record.meta_charge_estimate.currency} · ${record.meta_charge_estimate.market} · ${record.meta_charge_estimate.effective_on} · ${record.meta_charge_estimate.source}`
                    : 'Unknown — obtain a current Meta estimate before broadcast.'
                }}
              </p>
              <p
                v-if="record.meta_charge_estimate?.authority"
                class="text-n-slate-11"
              >
                Verified by Business Account admin ·
                {{ record.meta_charge_estimate.verified_at }}
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                type="button"
                :data-testid="`edit-template-${record.id}`"
                class="rounded border border-n-weak px-3 py-2"
                @click="edit(record)"
              >
                Edit as new revision
              </button>
              <Button
                v-if="resubmittableStatuses.includes(record.status)"
                :data-testid="`submit-template-${record.id}`"
                sm
                @click="submit(record)"
              >
                {{
                  record.status === 'draft'
                    ? 'Submit to Meta'
                    : 'Retry submission'
                }} </Button
              ><Button
                v-if="
                  ![
                    'draft',
                    'submission_pending',
                    'submission_failed',
                  ].includes(record.status)
                "
                data-testid="sync-meta-status"
                sm
                @click="reconcile(record)"
              >
                Sync Meta status
              </Button>
            </div>
          </div>
          <p v-if="record.rejection_reason" class="mt-2 text-n-ruby-11">
            Meta rejection: {{ record.rejection_reason }}
          </p>
          <p v-if="record.submission_failure" class="mt-2 text-n-ruby-11">
            Submission failed ({{ record.submission_failure.kind }}):
            {{ record.submission_failure.message }}
          </p>
          <details v-if="record.revisions?.length" class="mt-3">
            <summary class="cursor-pointer font-medium text-n-slate-12">
              Revision history
            </summary>
            <ol class="mt-2 grid gap-2 border-l border-n-weak pl-3">
              <li
                v-for="revision in record.revisions"
                :key="revision.revision"
                class="text-n-slate-11"
              >
                Revision {{ revision.revision }} · {{ revision.status }}
                <template v-if="revision.rejection_reason">
                  · {{ revision.rejection_reason }}
                </template>
                <span v-if="revision.current"> · current</span>
              </li>
            </ol>
          </details>
        </div>
      </section>
    </section>
  </main>
</template>
