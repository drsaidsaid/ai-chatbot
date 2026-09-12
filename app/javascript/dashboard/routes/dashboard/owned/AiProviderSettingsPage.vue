<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiProviderConnectionAPI from 'dashboard/api/aiProviderConnection';
import aiSubscriptionAPI from 'dashboard/api/aiSubscription';

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
const subscription = ref({
  status: 'inactive',
  used_ai_replies: 0,
  reserved_ai_replies: 0,
  remaining_ai_replies: 0,
  usage_percentage: 0,
  automation_allowed: false,
});
const availablePlans = ref([]);
const pendingRequests = ref([]);
const subscriptionAlerts = ref([]);
const separateCharges = ref({});
const requestStatus = ref('');

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
const usageWidth = computed(() =>
  Math.min(100, Math.max(0, Number(subscription.value.usage_percentage) || 0))
);
const upgradePlans = computed(() =>
  availablePlans.value.filter(
    plan => plan.included_ai_replies > subscription.value.included_ai_replies
  )
);
const currentPlan = computed(() =>
  availablePlans.value.find(plan => plan.id === subscription.value.plan_id)
);
const load = async () => {
  isLoading.value = true;
  try {
    const [providerResponse, subscriptionResponse] = await Promise.all([
      aiProviderConnectionAPI.get(),
      aiSubscriptionAPI.get(),
    ]);
    service.value = { ...service.value, ...providerResponse.data };
    subscription.value = {
      ...subscription.value,
      ...subscriptionResponse.data.subscription,
    };
    availablePlans.value = subscriptionResponse.data.available_plans || [];
    pendingRequests.value = subscriptionResponse.data.pending_requests || [];
    subscriptionAlerts.value = subscriptionResponse.data.alerts || [];
    separateCharges.value = subscriptionResponse.data.separate_charges || {};
  } finally {
    isLoading.value = false;
  }
};
const requestPlan = async (plan, purpose) => {
  requestStatus.value = 'requesting';
  try {
    await aiSubscriptionAPI.createRequest({
      ai_service_plan_id: plan.id,
      purpose,
    });
    requestStatus.value = 'requested';
    await load();
  } catch {
    requestStatus.value = 'failed';
  }
};
const requestTopUp = async () => {
  const plan = currentPlan.value;
  if (!plan?.top_up_ai_replies || !plan?.top_up_price) {
    requestStatus.value = 'failed';
    return;
  }
  requestStatus.value = 'requesting';
  try {
    await aiSubscriptionAPI.createRequest({
      ai_service_plan_id: plan.id,
      purpose: 'top_up',
    });
    requestStatus.value = 'requested';
    await load();
  } catch {
    requestStatus.value = 'failed';
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

        <section
          class="mt-8 border-t border-n-weak pt-6"
          aria-labelledby="subscription-title"
        >
          <h2
            id="subscription-title"
            class="text-lg font-semibold text-n-slate-12"
          >
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.TITLE') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.DESCRIPTION') }}
          </p>

          <div
            v-if="subscriptionAlerts.length"
            class="mt-4 rounded-md border border-n-ruby-6 bg-n-ruby-2 p-3 text-sm text-n-ruby-11"
            role="alert"
          >
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.OWNER_ALERT') }}
          </div>

          <div v-if="subscription.status === 'active'" class="mt-4">
            <div class="flex items-end justify-between gap-3">
              <div>
                <p class="text-sm font-medium text-n-slate-12">
                  {{ subscription.plan_name }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{ subscription.used_ai_replies }}
                  {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.USED') }} ·
                  {{ subscription.remaining_ai_replies }}
                  {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REMAINING') }}
                </p>
              </div>
              <p class="text-sm font-medium text-n-slate-12">
                {{ subscription.usage_percentage }}%
              </p>
            </div>
            <div
              class="mt-2 h-2 overflow-hidden rounded-full bg-n-solid-3"
              role="meter"
              :aria-valuenow="usageWidth"
              aria-valuemin="0"
              aria-valuemax="100"
            >
              <div
                class="h-full rounded-full bg-n-brand"
                :style="{ width: `${usageWidth}%` }"
              />
            </div>
            <p class="mt-2 text-xs text-n-slate-11">
              {{
                t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.RENEWS', {
                  date: subscription.renewal_date,
                })
              }}
            </p>
            <div
              v-if="!subscription.automation_allowed"
              class="mt-3 rounded-md border border-n-ruby-6 bg-n-ruby-2 p-3 text-sm text-n-ruby-11"
              role="alert"
            >
              {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.EXHAUSTED') }}
            </div>
            <div class="mt-4 flex flex-wrap items-end gap-2">
              <button
                v-if="currentPlan?.top_up_ai_replies"
                type="button"
                class="rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-12 disabled:opacity-50"
                :disabled="requestStatus === 'requesting'"
                @click="requestTopUp"
              >
                {{
                  t(
                    'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_TOP_UP',
                    {
                      count: currentPlan.top_up_ai_replies,
                      currency: currentPlan.currency,
                      price: currentPlan.top_up_price,
                    }
                  )
                }}
              </button>
              <button
                v-for="plan in upgradePlans"
                :key="plan.id"
                type="button"
                class="rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-12 disabled:opacity-50"
                :disabled="requestStatus === 'requesting'"
                @click="requestPlan(plan, 'upgrade')"
              >
                {{
                  t(
                    'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_UPGRADE',
                    { plan: plan.name }
                  )
                }}
              </button>
            </div>
          </div>
          <div
            v-else-if="subscription.status === 'renewal_due'"
            class="mt-4 rounded-md border border-n-ruby-6 bg-n-ruby-2 p-3"
          >
            <p class="text-sm text-n-ruby-11">
              {{
                t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.RENEWAL_DUE')
              }}
            </p>
            <button
              v-if="currentPlan"
              type="button"
              class="mt-3 rounded-md border border-n-ruby-7 px-3 py-2 text-sm font-medium text-n-ruby-11 disabled:opacity-50"
              :disabled="requestStatus === 'requesting'"
              @click="requestPlan(currentPlan, 'renewal')"
            >
              {{
                t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_RENEWAL')
              }}
            </button>
          </div>
          <div v-else class="mt-4 grid gap-3 sm:grid-cols-2">
            <article
              v-for="plan in availablePlans"
              :key="plan.id"
              class="rounded-md border border-n-weak p-3"
            >
              <p class="font-medium text-n-slate-12">{{ plan.name }}</p>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ plan.included_ai_replies }}
                {{
                  t(
                    'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REPLIES_MONTHLY'
                  )
                }}
              </p>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ plan.currency }} {{ plan.monthly_price }}
              </p>
              <button
                type="button"
                class="mt-3 rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-12 disabled:opacity-50"
                :disabled="requestStatus === 'requesting'"
                @click="requestPlan(plan, 'new_subscription')"
              >
                {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_PLAN') }}
              </button>
            </article>
          </div>
          <p
            v-if="pendingRequests.length"
            class="mt-3 text-sm text-n-slate-11"
          >
            {{
              t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.PENDING', {
                count: pendingRequests.length,
              })
            }}
          </p>
          <ul v-if="pendingRequests.length" class="mt-2 space-y-2">
            <li
              v-for="request in pendingRequests"
              :key="request.id"
              class="rounded-md border border-n-weak bg-n-solid-2 p-3 text-sm text-n-slate-12"
            >
              <p v-if="request.quoted_amount">
                {{ request.currency }} {{ request.quoted_amount }}
              </p>
              <p class="mt-1 text-n-slate-11">
                {{ request.payment_instructions }}
              </p>
            </li>
          </ul>
          <p
            v-if="requestStatus === 'requested'"
            class="mt-3 text-sm text-n-slate-12"
            role="status"
          >
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUESTED') }}
          </p>
          <p
            v-if="requestStatus === 'failed'"
            class="mt-3 text-sm text-n-ruby-11"
            role="alert"
          >
            {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_FAILED') }}
          </p>
        </section>

        <section class="mt-8 border-t border-n-weak pt-6">
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{
              t(
                'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.SEPARATE_COSTS'
              )
            }}
          </h2>
          <p class="mt-2 text-sm text-n-slate-11">
            {{ separateCharges.meta_messaging }}
          </p>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ separateCharges.advertising_spend }}
          </p>
          <p class="mt-1 text-sm text-n-slate-11">
            {{
              t(
                'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.PROVIDER_COSTS_PRIVATE'
              )
            }}
          </p>
        </section>
      </template>
    </section>
  </main>
</template>
