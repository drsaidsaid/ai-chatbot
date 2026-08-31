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
});
const model = ref('');
const apiKey = ref('');
const isLoading = ref(true);
const isSaving = ref(false);
const isChecking = ref(false);
const isDisabling = ref(false);

const isConfigured = computed(
  () => connection.value.status === 'active' && connection.value.has_credentials
);

const statusLabel = computed(() =>
  isConfigured.value
    ? t('AI_LEAD_EMPLOYEE.AI_PROVIDER.CONNECTED')
    : t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NOT_CONNECTED')
);

const healthLabel = computed(() => {
  if (!connection.value.last_health_status) {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NOT_CHECKED');
  }
  if (connection.value.last_health_status === 'healthy') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.HEALTHY');
  }
  return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NEEDS_ATTENTION');
});

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await aiProviderConnectionAPI.get();
    connection.value = { ...connection.value, ...data };
    model.value = data.model || '';
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
    };
    if (apiKey.value.trim()) payload.api_key = apiKey.value.trim();

    const { data } = await aiProviderConnectionAPI.save(payload);
    connection.value = { ...connection.value, ...data };
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
    const { data } = await aiProviderConnectionAPI.healthCheck();
    connection.value = {
      ...connection.value,
      last_health_status: data.status,
      last_health_checked_at: data.checked_at,
      last_health_failure_class: data.failure_class || null,
    };
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
