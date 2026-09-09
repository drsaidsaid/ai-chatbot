<script setup>
import { onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import WhatsappConnectionAPI from 'dashboard/api/whatsappConnection';

const { t } = useI18n();
const prefix = 'AI_LEAD_EMPLOYEE.WHATSAPP_CONNECTION';
const connection = ref({ status: 'not_connected' });
const form = reactive({
  name: '',
  phone_number: '',
  phone_number_id: '',
  business_account_id: '',
  api_key: '',
  app_secret: '',
});
const fields = [
  'name',
  'phone_number',
  'phone_number_id',
  'business_account_id',
  'api_key',
  'app_secret',
];
const loading = ref(true);
const busy = ref(false);
const loadFailed = ref(false);
const error = ref('');
const notice = ref('');

const apply = data => {
  connection.value = data;
  fields
    .filter(field => !['api_key', 'app_secret'].includes(field))
    .forEach(field => {
      form[field] = data[field] || '';
    });
};
const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    apply((await WhatsappConnectionAPI.get()).data);
    loadFailed.value = false;
  } catch {
    error.value = t(`${prefix}.LOAD_ERROR`);
    loadFailed.value = true;
  } finally {
    loading.value = false;
  }
};
const action = async (operation, message) => {
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    apply((await operation()).data);
    notice.value = t(`${prefix}.${message}`);
    return true;
  } catch {
    error.value = t(`${prefix}.ACTION_ERROR`);
    return false;
  } finally {
    busy.value = false;
  }
};
const save = async () => {
  const values = Object.fromEntries(
    Object.entries(form).filter(([, value]) => value !== '')
  );
  if (await action(() => WhatsappConnectionAPI.save(values), 'SAVED')) {
    form.api_key = '';
    form.app_secret = '';
  }
};
const date = value =>
  value ? new Date(value).toLocaleString() : t(`${prefix}.NOT_YET`);
const isSecret = field => ['api_key', 'app_secret'].includes(field);
onMounted(load);
</script>

<template>
  <main class="min-w-0 flex-1 overflow-auto bg-n-background">
    <header class="border-b border-n-weak px-4 py-5 md:px-6">
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ t(`${prefix}.TITLE`) }}
      </h1>
      <p class="mt-1 max-w-2xl text-sm text-n-slate-11">
        {{ t(`${prefix}.INTRO`) }}
      </p>
    </header>
    <div class="mx-auto grid max-w-5xl gap-5 p-4 md:p-6">
      <p v-if="loading" role="status">{{ t(`${prefix}.LOADING`) }}</p>
      <div
        v-if="error"
        role="alert"
        class="rounded-lg border border-n-weak bg-n-solid-2 p-4 text-sm"
      >
        {{ error }}
        <button
          v-if="loadFailed"
          class="ml-2 min-h-10 underline"
          type="button"
          @click="load"
        >
          {{ t(`${prefix}.REFRESH`) }}
        </button>
      </div>
      <p v-if="notice" role="status" class="text-sm text-n-slate-11">
        {{ notice }}
      </p>
      <template v-if="!loading && !loadFailed">
        <section
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4 md:p-5"
          :aria-label="t(`${prefix}.HEALTH`)"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0">
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t(`${prefix}.STATUS.${connection.status}`) }}
              </h2>
              <p class="mt-2 max-w-2xl text-sm text-n-slate-11">
                {{ t(`${prefix}.GUIDANCE.${connection.status}`) }}
              </p>
            </div>
            <button
              type="button"
              class="min-h-10 shrink-0 rounded-lg border border-n-weak px-3 text-sm"
              :disabled="busy"
              @click="load"
            >
              {{ t(`${prefix}.REFRESH`) }}
            </button>
          </div>
          <p
            v-for="code in [
              connection.webhook_error_code,
              connection.health_error_code,
              connection.receiving_error_code,
            ].filter(Boolean)"
            :key="code"
            class="mt-3 text-sm text-n-slate-12"
          >
            {{ t(`${prefix}.ERRORS.${code}`) }}
          </p>
          <template v-if="connection.inbox_id">
            <dl class="mt-5 grid gap-4 text-sm sm:grid-cols-2">
              <div>
                <dt class="text-n-slate-11">{{ t(`${prefix}.ACCEPTED`) }}</dt>
                <dd class="mt-1 font-medium">
                  {{ date(connection.last_accepted_at) }}
                </dd>
              </div>
              <div>
                <dt class="text-n-slate-11">{{ t(`${prefix}.PROCESSED`) }}</dt>
                <dd class="mt-1 font-medium">
                  {{ date(connection.last_processed_at) }}
                </dd>
              </div>
              <div>
                <dt class="text-n-slate-11">{{ t(`${prefix}.CHECKED`) }}</dt>
                <dd class="mt-1">{{ date(connection.health_checked_at) }}</dd>
              </div>
              <div>
                <dt class="text-n-slate-11">{{ t(`${prefix}.PENDING`) }}</dt>
                <dd class="mt-1">{{ connection.pending_count || 0 }}</dd>
              </div>
            </dl>
            <p
              v-if="connection.awaiting_delivery_count"
              class="mt-3 text-sm text-n-slate-11"
            >
              {{
                t(`${prefix}.AWAITING_DELIVERY`, {
                  count: connection.awaiting_delivery_count,
                })
              }}
            </p>
            <div class="mt-5 flex flex-wrap gap-2">
              <button
                type="button"
                class="min-h-11 rounded-lg border border-n-weak px-4 text-sm font-medium"
                :disabled="busy"
                @click="
                  action(() => WhatsappConnectionAPI.check(), 'CHECK_COMPLETE')
                "
              >
                {{ t(`${prefix}.CHECK`) }}
              </button>
              <button
                v-if="
                  connection.pending_count || connection.awaiting_delivery_count
                "
                type="button"
                class="min-h-11 rounded-lg border border-n-weak px-4 text-sm font-medium"
                :disabled="busy"
                @click="
                  action(
                    () => WhatsappConnectionAPI.retryReceiving(),
                    'RETRY_QUEUED'
                  )
                "
              >
                {{ t(`${prefix}.RETRY`) }}
              </button>
            </div>
          </template>
        </section>
        <form
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4 md:p-5"
          @submit.prevent="save"
        >
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ t(`${prefix}.DETAILS`) }}
          </h2>
          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <label
              v-for="field in fields"
              :key="field"
              :for="`whatsapp-${field}`"
              class="grid min-w-0 gap-1.5 text-sm font-medium"
            >
              {{ t(`${prefix}.FIELDS.${field}`) }}
              <input
                :id="`whatsapp-${field}`"
                v-model="form[field]"
                :name="field"
                :type="isSecret(field) ? 'password' : 'text'"
                :autocomplete="isSecret(field) ? 'new-password' : 'off'"
                :required="
                  !isSecret(field) || !connection[`${field}_configured`]
                "
                :disabled="busy"
                class="h-11 min-w-0 w-full rounded-lg border border-n-weak bg-n-background px-3 font-normal focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
              />
              <span
                v-if="isSecret(field) && connection[`${field}_configured`]"
                class="text-xs font-normal text-n-slate-11"
                >{{ t(`${prefix}.SECRET_SAVED`) }}</span
              >
            </label>
          </div>
          <p class="mt-4 text-sm text-n-slate-11">
            {{ t(`${prefix}.SECRET_HELP`) }}
          </p>
          <button
            type="submit"
            class="mt-5 min-h-11 rounded-lg bg-n-brand px-5 text-sm font-medium text-white disabled:opacity-50"
            :disabled="busy"
          >
            {{ t(`${prefix}.${busy ? 'WORKING' : 'SAVE'}`) }}
          </button>
        </form>
        <section
          v-if="connection.callback_url"
          class="rounded-xl border border-n-weak p-4 text-sm"
        >
          <h2 class="font-medium">{{ t(`${prefix}.CALLBACK`) }}</h2>
          <p class="mt-2 break-all font-mono text-xs">
            {{ connection.callback_url }}
          </p>
          <p class="mt-2 text-n-slate-11">{{ t(`${prefix}.CALLBACK_HELP`) }}</p>
        </section>
      </template>
    </div>
  </main>
</template>
