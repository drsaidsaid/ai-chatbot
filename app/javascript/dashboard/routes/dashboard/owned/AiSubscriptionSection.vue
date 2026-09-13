<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiSubscriptionAPI from 'dashboard/api/aiSubscription';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const subscription = ref({
  status: 'inactive',
  used_ai_replies: 0,
  reserved_ai_replies: 0,
  reconciliation_required_ai_replies: 0,
  remaining_ai_replies: 0,
  usage_percentage: 0,
  automation_allowed: false,
});
const availablePlans = ref([]);
const pendingRequests = ref([]);
const subscriptionAlerts = ref([]);
const separateCharges = ref({});
const requestStatus = ref('');

const usageWidth = computed(() =>
  Math.min(100, Math.max(0, Number(subscription.value.usage_percentage) || 0))
);
const currentPlan = computed(() =>
  availablePlans.value.find(plan => plan.id === subscription.value.plan_id)
);
const upgradePlans = computed(() =>
  availablePlans.value.filter(
    plan =>
      plan.included_ai_replies > subscription.value.included_ai_replies &&
      Number(plan.monthly_price) > Number(currentPlan.value?.monthly_price) &&
      plan.currency === currentPlan.value?.currency
  )
);

const load = async () => {
  const response = await aiSubscriptionAPI.get();
  subscription.value = { ...subscription.value, ...response.data.subscription };
  availablePlans.value = response.data.available_plans || [];
  pendingRequests.value = response.data.pending_requests || [];
  subscriptionAlerts.value = response.data.alerts || [];
  separateCharges.value = response.data.separate_charges || {};
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
  await requestPlan(plan, 'top_up');
};

onMounted(load);
</script>

<template>
  <section
    class="mt-8 border-t border-n-weak pt-6"
    aria-labelledby="subscription-title"
  >
    <h2 id="subscription-title" class="text-lg font-semibold text-n-slate-12">
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
            {{
              t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.USAGE_SUMMARY', {
                used: subscription.used_ai_replies,
                remaining: subscription.remaining_ai_replies,
              })
            }}
          </p>
        </div>
        <p class="text-sm font-medium text-n-slate-12">
          {{
            t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.USAGE_PERCENTAGE', {
              value: subscription.usage_percentage,
            })
          }}
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
      <p
        v-if="subscription.reconciliation_required_ai_replies"
        class="mt-2 text-xs text-n-amber-11"
        role="status"
      >
        {{
          t(
            'AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.RECONCILIATION_REQUIRED',
            { count: subscription.reconciliation_required_ai_replies }
          )
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
        <Button
          v-if="currentPlan?.top_up_ai_replies"
          variant="outline"
          color="slate"
          size="sm"
          :disabled="requestStatus === 'requesting'"
          :label="
            t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_TOP_UP', {
              count: currentPlan.top_up_ai_replies,
              currency: currentPlan.currency,
              price: currentPlan.top_up_price,
            })
          "
          @click="requestTopUp"
        />
        <Button
          v-for="plan in upgradePlans"
          :key="plan.id"
          variant="outline"
          color="slate"
          size="sm"
          :disabled="requestStatus === 'requesting'"
          :label="
            t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_UPGRADE', {
              plan: plan.name,
            })
          "
          @click="requestPlan(plan, 'upgrade')"
        />
      </div>
    </div>
    <div
      v-else-if="subscription.status === 'renewal_due'"
      class="mt-4 rounded-md border border-n-ruby-6 bg-n-ruby-2 p-3"
    >
      <p class="text-sm text-n-ruby-11">
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.RENEWAL_DUE') }}
      </p>
      <Button
        v-if="currentPlan"
        class="mt-3"
        variant="outline"
        color="ruby"
        size="sm"
        :disabled="requestStatus === 'requesting'"
        :label="t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_RENEWAL')"
        @click="requestPlan(currentPlan, 'renewal')"
      />
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
          {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REPLIES_MONTHLY') }}
        </p>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ plan.currency }} {{ plan.monthly_price }}
        </p>
        <Button
          class="mt-3"
          variant="outline"
          color="slate"
          size="sm"
          :disabled="requestStatus === 'requesting'"
          :label="t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.REQUEST_PLAN')"
          @click="requestPlan(plan, 'new_subscription')"
        />
      </article>
    </div>
    <p v-if="pendingRequests.length" class="mt-3 text-sm text-n-slate-11">
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
        <p class="mt-1 text-n-slate-11">{{ request.payment_instructions }}</p>
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

    <section class="mt-8 border-t border-n-weak pt-6">
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.SEPARATE_COSTS') }}
      </h2>
      <p class="mt-2 text-sm text-n-slate-11">
        {{ separateCharges.meta_messaging }}
      </p>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ separateCharges.advertising_spend }}
      </p>
      <p class="mt-1 text-sm text-n-slate-11">
        {{
          t('AI_LEAD_EMPLOYEE.AI_PROVIDER.SUBSCRIPTION.PROVIDER_COSTS_PRIVATE')
        }}
      </p>
    </section>
  </section>
</template>
