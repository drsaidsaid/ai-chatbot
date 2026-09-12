<script setup>
/* eslint-disable vue/no-bare-strings-in-template */
import { computed, onMounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import whatsappTemplatesAPI from 'dashboard/api/whatsappTemplates';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const templates = ref([]);
const saving = ref(false);
const form = ref({
  inbox_id: '',
  name: '',
  language: 'en_US',
  category: 'UTILITY',
  body: '',
  buttons: [],
});
const inboxes = computed(() =>
  store.getters['inboxes/getInboxes'].filter(
    inbox => inbox.channel_type === 'Channel::Whatsapp'
  )
);

const load = async () => {
  await store.dispatch('inboxes/get');
  const { data } = await whatsappTemplatesAPI.get();
  templates.value = data;
};

const save = async () => {
  saving.value = true;
  try {
    const variables = [...form.value.body.matchAll(/\{\{\s*(\d+)\s*\}\}/g)].map(
      match => ({ position: Number(match[1]) })
    );
    const { data } = await whatsappTemplatesAPI.create({
      ...form.value,
      variables,
    });
    templates.value.unshift(data);
    form.value = {
      inbox_id: form.value.inbox_id,
      name: '',
      language: 'en_US',
      category: 'UTILITY',
      body: '',
      buttons: [],
    };
    useAlert('Draft saved. Local validation is not Meta approval.');
  } catch (error) {
    useAlert(
      error.response?.data?.error || 'Template draft could not be saved.'
    );
  } finally {
    saving.value = false;
  }
};

const submit = async record => {
  await whatsappTemplatesAPI.submit(record.id);
  record.status = 'submission_pending';
  record.meta_approval = 'submission_pending';
  useAlert('Submitted for Meta review. No customer message was sent.');
};

const reconcile = async record => {
  await whatsappTemplatesAPI.reconcile(record.id);
  useAlert('Reconciliation requested; the template was not submitted again.');
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
              pattern="[a-z0-9_]+"
              class="mt-1 w-full rounded border border-n-weak p-2" /></label
          ><label class="text-sm font-medium text-n-slate-12"
            >Language<input
              v-model.trim="form.language"
              required
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
        <aside class="rounded bg-n-solid-2 p-4 text-sm text-n-slate-12">
          <p class="font-medium">Recipient preview</p>
          <p class="mt-2 whitespace-pre-wrap">
            {{ form.body || 'Your template text will appear here.' }}
          </p>
          <p class="mt-2 text-n-slate-11">
            Use numbered variables such as &#123;&#123;1&#125;&#125;. They are
            checked before saving, but only Meta can approve a template.
          </p>
        </aside>
        <Button type="submit" :is-loading="saving">Save draft</Button>
      </form>
      <section>
        <h2 class="text-lg font-semibold text-n-slate-12">Saved templates</h2>
        <p class="mt-1 text-sm text-n-slate-11">
          Missing Meta pricing is shown as unknown, never as zero.
        </p>
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
                    ? `${record.meta_charge_estimate.amount} ${record.meta_charge_estimate.currency} · ${record.meta_charge_estimate.market} · ${record.meta_charge_estimate.source}`
                    : 'Unknown — obtain a current Meta estimate before broadcast.'
                }}
              </p>
            </div>
            <div class="flex gap-2">
              <Button
                v-if="record.status === 'draft'"
                sm
                @click="submit(record)"
              >
                Submit to Meta </Button
              ><Button
                v-if="record.status === 'unknown'"
                sm
                @click="reconcile(record)"
              >
                Reconcile
              </Button>
            </div>
          </div>
          <p v-if="record.rejection_reason" class="mt-2 text-n-ruby-11">
            Meta rejection: {{ record.rejection_reason }}
          </p>
        </div>
      </section>
    </section>
  </main>
</template>
