<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import aiProviderConnectionAPI from 'dashboard/api/aiProviderConnection';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();

const connection = ref({
  provider: 'openrouter',
  model: '',
  status: 'disabled',
  has_credentials: false,
  last_health_status: null,
  last_health_checked_at: null,
  last_health_failure_class: null,
  last_health_model: null,
  last_health_reply_token_limit: null,
  last_health_configuration_version: null,
  last_health_checked_at_label: null,
  readiness_status: 'disabled',
  configuration_version: 1,
  reply_token_limit: 512,
  daily_request_limit: 0,
  requests_used_today: 0,
  requests_remaining_today: 0,
  usage_resets_at: null,
  usage_resets_at_label: null,
  automation_allowed: false,
  automation_paused_reason: 'provider_disabled',
  cost_usd_today: null,
  cost_data_complete: false,
});
const model = ref('');
const apiKey = ref('');
const replyTokenLimit = ref(512);
const dailyRequestLimit = ref(0);
const isLoading = ref(true);
const isSaving = ref(false);
const isChecking = ref(false);
const isDisabling = ref(false);

const isConfigured = computed(
  () => connection.value.status === 'active' && connection.value.has_credentials
);

const statusLabel = computed(() =>
  isConfigured.value
    ? t('AI_LEAD_EMPLOYEE.AI_PROVIDER.CONFIGURED')
    : t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NOT_CONNECTED')
);

const healthLabel = computed(() => {
  if (connection.value.readiness_status === 'disabled') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.DISABLED_STATUS');
  }
  if (connection.value.readiness_status === 'not_checked') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NOT_CHECKED');
  }
  if (connection.value.readiness_status === 'healthy') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.HEALTHY');
  }
  return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NEEDS_ATTENTION');
});

const usageLabel = computed(
  () =>
    `${connection.value.requests_used_today} / ${connection.value.daily_request_limit}`
);

const costLabel = computed(() => {
  if (
    !connection.value.cost_data_complete ||
    connection.value.cost_usd_today === null
  ) {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.COST_UNKNOWN');
  }
  return `$${Number(connection.value.cost_usd_today).toFixed(4)}`;
});

const resetLabel = computed(() => {
  return connection.value.usage_resets_at_label || '';
});

const hasHealthObservation = computed(
  () =>
    connection.value.last_health_checked_at &&
    connection.value.last_health_configuration_version
);

const failureGuidance = computed(() => {
  const failure = connection.value.last_health_failure_class;
  if (!failure) return [];
  const messages = {
    authentication_failure: t(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.AUTHENTICATION_FAILURE'
    ),
    insufficient_credits: t(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.INSUFFICIENT_CREDITS'
    ),
    rate_limit: t('AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.RATE_LIMIT'),
    timeout: t('AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.TIMEOUT'),
    transport_failure: t(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.TRANSPORT_FAILURE'
    ),
    invalid_response: t(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.INVALID_RESPONSE'
    ),
    safety_refusal: t('AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.SAFETY_REFUSAL'),
    usage_limit_exhausted: t(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.USAGE_LIMIT_EXHAUSTED'
    ),
    provider_disabled: t(
      'AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.PROVIDER_DISABLED'
    ),
  };
  const message = messages[failure];
  if (!message) {
    return [
      t('AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.UNKNOWN'),
      t('AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.RETRY'),
    ];
  }
  const retry =
    failure === 'insufficient_credits'
      ? t('AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.RETRY_AFTER_CREDITS')
      : t('AI_LEAD_EMPLOYEE.AI_PROVIDER.FAILURE.RETRY');
  return [message, retry];
});

const pauseLabel = computed(() => {
  const reason = connection.value.automation_paused_reason;
  if (!reason) return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.AUTOMATION_ALLOWED');
  if (reason === 'usage_limit_exhausted') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.USAGE_LIMIT_EXHAUSTED');
  }
  return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.PROVIDER_DISABLED');
});

const applyConnection = data => {
  connection.value = { ...connection.value, ...data };
  if (Object.hasOwn(data, 'model')) model.value = data.model || '';
  if (Object.hasOwn(data, 'reply_token_limit')) {
    replyTokenLimit.value = data.reply_token_limit;
  }
  if (Object.hasOwn(data, 'daily_request_limit')) {
    dailyRequestLimit.value = data.daily_request_limit;
  }
};

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await aiProviderConnectionAPI.get();
    applyConnection(data);
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const payload = {
      provider: 'openrouter',
      model: model.value.trim(),
      reply_token_limit: Number(replyTokenLimit.value),
      daily_request_limit: Number(dailyRequestLimit.value),
    };
    if (apiKey.value.trim()) payload.api_key = apiKey.value.trim();

    const { data } = await aiProviderConnectionAPI.save(payload);
    applyConnection(data);
    apiKey.value = '';
    useAlert(t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SAVED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const checkHealth = async () => {
  isChecking.value = true;
  try {
    await aiProviderConnectionAPI.healthCheck();
    const { data } = await aiProviderConnectionAPI.get();
    applyConnection(data);
    useAlert(t('AI_LEAD_EMPLOYEE.AI_PROVIDER.HEALTH_CHECKED'));
  } catch {
    useAlert(t('AI_LEAD_EMPLOYEE.AI_PROVIDER.HEALTH_ERROR'));
  } finally {
    isChecking.value = false;
  }
};

const disable = async () => {
  isDisabling.value = true;
  try {
    const { data } = await aiProviderConnectionAPI.disable();
    connection.value = { ...connection.value, ...data };
    apiKey.value = '';
    useAlert(t('AI_LEAD_EMPLOYEE.AI_PROVIDER.DISABLED'));
  } finally {
    isDisabling.value = false;
  }
};

onMounted(load);
</script>

<template>
  <main class="flex-1 min-w-0 bg-n-background p-4 sm:p-6">
    <section class="max-w-3xl mx-auto">
      <p class="text-xs font-medium uppercase text-n-slate-11 tracking-normal">
        {{ t('AI_LEAD_EMPLOYEE.PRODUCT_NAME') }}
      </p>
      <h1 class="mt-2 text-2xl font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.TITLE') }}
      </h1>
      <p class="mt-2 max-w-2xl text-sm text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.DESCRIPTION') }}
      </p>

      <div v-if="isLoading" class="mt-6 text-sm text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.LOADING') }}
      </div>
      <template v-else>
        <div class="mt-6 grid gap-4 border-y border-n-weak py-4 sm:grid-cols-2">
          <div>
            <p class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.CONNECTION') }}
            </p>
            <p class="mt-1 text-sm font-medium text-n-slate-12">
              {{ statusLabel }}
            </p>
          </div>
          <div>
            <p class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.HEALTH') }}
            </p>
            <p class="mt-1 text-sm font-medium text-n-slate-12">
              {{ healthLabel }}
            </p>
          </div>
          <div>
            <p class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.USAGE_TODAY') }}
            </p>
            <p class="mt-1 text-sm font-medium text-n-slate-12">
              {{ usageLabel }}
            </p>
            <p class="mt-1 text-xs text-n-slate-11">
              {{
                t('AI_LEAD_EMPLOYEE.AI_PROVIDER.REQUESTS_REMAINING', {
                  count: connection.requests_remaining_today,
                })
              }}
            </p>
            <p v-if="resetLabel" class="mt-1 text-xs text-n-slate-11">
              {{
                t('AI_LEAD_EMPLOYEE.AI_PROVIDER.RESETS_AT', {
                  time: resetLabel,
                })
              }}
            </p>
          </div>
          <div>
            <p class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.COST_TODAY') }}
            </p>
            <p class="mt-1 text-sm font-medium text-n-slate-12">
              {{ costLabel }}
            </p>
          </div>
        </div>

        <div
          class="mt-4 rounded-md border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
          role="status"
        >
          {{ pauseLabel }}
        </div>

        <dl
          v-if="hasHealthObservation"
          class="mt-4 grid gap-2 rounded-md border border-n-weak px-3 py-3 text-sm sm:grid-cols-2"
        >
          <div>
            <dt class="text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.LAST_CHECK') }}
            </dt>
            <dd class="font-medium text-n-slate-12">
              {{ connection.last_health_checked_at_label }}
            </dd>
          </div>
          <div>
            <dt class="text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.CHECKED_CONFIGURATION') }}
            </dt>
            <dd class="font-medium text-n-slate-12">
              {{
                t('AI_LEAD_EMPLOYEE.AI_PROVIDER.CHECKED_CONFIGURATION_VALUE', {
                  model: connection.last_health_model,
                  tokens: connection.last_health_reply_token_limit,
                  revision: connection.last_health_configuration_version,
                })
              }}
            </dd>
          </div>
        </dl>

        <div
          v-if="failureGuidance.length"
          class="mt-4 rounded-md border border-n-ruby-6 bg-n-ruby-2 px-3 py-3 text-sm text-n-ruby-11"
          role="alert"
        >
          <p>{{ failureGuidance[0] }}</p>
          <p class="mt-1">
            {{ failureGuidance[1] }}
            {{
              t('AI_LEAD_EMPLOYEE.AI_PROVIDER.CHECKED_BUDGET', {
                count: connection.reply_token_limit,
              })
            }}
          </p>
        </div>

        <form class="mt-6 grid gap-5" @submit.prevent="save">
          <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.PROVIDER') }}
            <select
              disabled
              class="h-10 rounded-md border border-n-weak bg-n-solid-2 px-3 text-sm"
            >
              <option>
                {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.OPENROUTER') }}
              </option>
            </select>
          </label>
          <div class="grid gap-5 sm:grid-cols-2">
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.REPLY_TOKEN_LIMIT') }}
              <input
                v-model.number="replyTokenLimit"
                required
                type="number"
                min="1"
                max="4096"
                class="h-10 rounded-md border border-n-weak bg-n-background px-3 text-sm"
              />
              <span class="text-xs font-normal text-n-slate-11">
                {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.REPLY_TOKEN_HELP') }}
              </span>
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.DAILY_REQUEST_LIMIT') }}
              <input
                v-model.number="dailyRequestLimit"
                required
                type="number"
                min="0"
                max="100000"
                class="h-10 rounded-md border border-n-weak bg-n-background px-3 text-sm"
              />
              <span class="text-xs font-normal text-n-slate-11">
                {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.DAILY_LIMIT_HELP') }}
              </span>
            </label>
          </div>
          <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MODEL') }}
            <input
              v-model="model"
              required
              type="text"
              class="h-10 rounded-md border border-n-weak bg-n-background px-3 text-sm"
              :placeholder="t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MODEL_PLACEHOLDER')"
            />
          </label>
          <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.API_KEY') }}
            <input
              v-model="apiKey"
              :required="!isConfigured"
              type="password"
              autocomplete="new-password"
              class="h-10 rounded-md border border-n-weak bg-n-background px-3 text-sm"
              :placeholder="
                isConfigured
                  ? t('AI_LEAD_EMPLOYEE.AI_PROVIDER.KEY_SAVED')
                  : t('AI_LEAD_EMPLOYEE.AI_PROVIDER.KEY_PLACEHOLDER')
              "
            />
            <span class="text-xs font-normal text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.KEY_HELP') }}
            </span>
          </label>

          <div class="flex flex-wrap gap-2 border-t border-n-weak pt-5">
            <button
              type="submit"
              class="inline-flex h-9 items-center gap-2 rounded-md bg-n-brand px-3 text-sm font-medium text-white disabled:opacity-50"
              :disabled="isSaving"
            >
              <Icon icon="i-lucide-save" />
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SAVE') }}
            </button>
            <button
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-md border border-n-weak px-3 text-sm font-medium text-n-slate-12 disabled:opacity-50"
              :disabled="!isConfigured || isChecking"
              @click="checkHealth"
            >
              <Icon icon="i-lucide-activity" />
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.CHECK') }}
            </button>
            <button
              type="button"
              class="inline-flex h-9 items-center gap-2 rounded-md border border-n-ruby-6 px-3 text-sm font-medium text-n-ruby-11 disabled:opacity-50"
              :disabled="!isConfigured || isDisabling"
              @click="disable"
            >
              <Icon icon="i-lucide-power" />
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.DISABLE') }}
            </button>
          </div>
        </form>
      </template>
    </section>
  </main>
</template>
