<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiProviderConnectionAPI from 'dashboard/api/aiProviderConnection';

const { t } = useI18n();
const service = ref({
  managed_service: true,
  service_status: 'disabled',
  readiness_status: 'disabled',
  daily_request_limit: 0,
  requests_used_today: 0,
  requests_remaining_today: 0,
  usage_resets_at_label: null,
  automation_allowed: false,
  automation_paused_reason: 'provider_disabled',
});
const isLoading = ref(true);

const statusLabel = computed(() =>
  service.value.service_status === 'active'
    ? t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_ACTIVE')
    : t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_UNAVAILABLE')
);
const healthLabel = computed(() => {
  if (service.value.readiness_status === 'healthy') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.HEALTHY');
  }
  if (service.value.readiness_status === 'not_checked') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NOT_CHECKED');
  }
  if (service.value.readiness_status === 'failed') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.NEEDS_ATTENTION');
  }
  return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.DISABLED_STATUS');
});
const usageLabel = computed(
  () =>
    `${service.value.requests_used_today} / ${service.value.daily_request_limit}`
);
const pauseLabel = computed(() => {
  if (!service.value.automation_paused_reason) {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.AUTOMATION_ALLOWED');
  }
  if (service.value.automation_paused_reason === 'usage_limit_exhausted') {
    return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.USAGE_LIMIT_EXHAUSTED');
  }
  return t('AI_LEAD_EMPLOYEE.AI_PROVIDER.PAUSE.PROVIDER_DISABLED');
});
const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await aiProviderConnectionAPI.get();
    service.value = { ...service.value, ...data };
  } finally {
    isLoading.value = false;
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
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_TITLE') }}
      </h1>
      <p class="mt-2 max-w-2xl text-sm text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_DESCRIPTION') }}
      </p>

      <div v-if="isLoading" class="mt-6 text-sm text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.LOADING') }}
      </div>
      <template v-else>
        <div class="mt-6 grid gap-4 border-y border-n-weak py-4 sm:grid-cols-2">
          <div>
            <p class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SERVICE') }}
            </p>
            <p class="mt-1 text-sm font-medium text-n-slate-12">
              {{ statusLabel }}
            </p>
          </div>
          <div>
            <p class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.READINESS') }}
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
                  count: service.requests_remaining_today,
                })
              }}
            </p>
            <p
              v-if="service.usage_resets_at_label"
              class="mt-1 text-xs text-n-slate-11"
            >
              {{
                t('AI_LEAD_EMPLOYEE.AI_PROVIDER.RESETS_AT', {
                  time: service.usage_resets_at_label,
                })
              }}
            </p>
          </div>
          <div>
            <p class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGEMENT') }}
            </p>
            <p class="mt-1 text-sm text-n-slate-12">
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.PLATFORM_MANAGED') }}
            </p>
          </div>
        </div>

        <div
          class="mt-4 rounded-md border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
          role="status"
        >
          {{ pauseLabel }}
        </div>
        <div
          v-if="service.readiness_status === 'failed'"
          class="mt-4 rounded-md border border-n-ruby-6 bg-n-ruby-2 px-3 py-3 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.MANAGED_ATTENTION') }}
        </div>
        <p
          v-if="service.last_health_checked_at_label"
          class="mt-4 text-xs text-n-slate-11"
        >
          {{
            t('AI_LEAD_EMPLOYEE.AI_PROVIDER.LAST_CHECK_VALUE', {
              time: service.last_health_checked_at_label,
            })
          }}
        </p>
      </template>
    </section>
  </main>
</template>
