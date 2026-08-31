<script>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
export default {};
</script>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Icon from 'next/icon/Icon.vue';
import BookingConfigurationAPI from 'dashboard/api/bookingConfiguration';
import QualificationConfigurationAPI from 'dashboard/api/qualificationConfiguration';

const props = defineProps({ section: { type: String, required: true } });
const { accountScopedRoute } = useAccount();
const loading = ref(true);
const saving = ref(false);
const qualification = reactive({
  questions: [],
  budget_ranges: [],
  follow_up: {},
});
const booking = reactive({
  timezone: 'UTC',
  duration_minutes: 30,
  minimum_notice_minutes: 60,
  working_days: [],
  allowed_hours: { start: '09:00', end: '17:00' },
});

const sections = computed(() => [
  {
    key: 'ai_provider',
    routeName: 'owned_ai_provider_settings',
    label: 'AI provider',
    icon: 'i-lucide-brain-circuit',
  },
  {
    key: 'offers_qualification',
    routeName: 'ai_lead_employee_settings_offers_qualification',
    label: 'Offers and qualification',
    icon: 'i-lucide-tag',
  },
  {
    key: 'booking_business_hours',
    routeName: 'ai_lead_employee_settings_booking_business_hours',
    label: 'Booking and business hours',
    icon: 'i-lucide-calendar-days',
  },
  {
    key: 'team_assignment',
    routeName: 'ai_lead_employee_settings_team_assignment',
    label: 'Team assignment',
    icon: 'i-lucide-users',
  },
  {
    key: 'follow_ups',
    routeName: 'ai_lead_employee_settings_follow_ups',
    label: 'Follow-ups',
    icon: 'i-lucide-message-circle',
  },
  {
    key: 'alerts',
    routeName: 'ai_lead_employee_settings_alerts',
    label: 'Alerts',
    icon: 'i-lucide-bell',
  },
  {
    key: 'whatsapp_connection',
    routeName: 'ai_lead_employee_settings_whatsapp_connection',
    label: 'WhatsApp connection',
    icon: 'i-lucide-phone',
  },
]);
const activeSection = computed(
  () =>
    sections.value.find(item => item.key === props.section) || sections.value[1]
);
const isQualification = computed(() =>
  ['offers_qualification', 'follow_ups'].includes(activeSection.value.key)
);
const isBooking = computed(
  () => activeSection.value.key === 'booking_business_hours'
);
const nativeDestination = computed(
  () =>
    ({
      team_assignment: { label: 'Open teams', route: 'settings_teams_list' },
      alerts: { label: 'Open inboxes', route: 'settings_inbox_list' },
      whatsapp_connection: {
        label: 'Open inboxes',
        route: 'settings_inbox_list',
      },
    })[activeSection.value.key]
);

const load = async () => {
  loading.value = true;
  try {
    const [qualificationResponse, bookingResponse] = await Promise.all([
      QualificationConfigurationAPI.get(),
      BookingConfigurationAPI.get(),
    ]);
    Object.assign(qualification, qualificationResponse.data);
    Object.assign(booking, bookingResponse.data);
  } catch {
    useAlert('Unable to load these settings.');
  } finally {
    loading.value = false;
  }
};
const saveQualification = async () => {
  saving.value = true;
  try {
    Object.assign(
      qualification,
      (await QualificationConfigurationAPI.update(qualification)).data
    );
    useAlert('Qualification settings saved.');
  } catch {
    useAlert('Unable to save qualification settings.');
  } finally {
    saving.value = false;
  }
};
const saveBooking = async () => {
  saving.value = true;
  try {
    Object.assign(
      booking,
      (await BookingConfigurationAPI.update(booking)).data
    );
    useAlert('Booking settings saved.');
  } catch {
    useAlert('Unable to save booking settings.');
  } finally {
    saving.value = false;
  }
};
watch(() => props.section, load);
onMounted(load);
</script>

<template>
  <main class="flex h-full min-w-0 flex-1 bg-n-background">
    <aside
      class="hidden w-64 shrink-0 border-r border-n-weak bg-n-solid-1 p-4 md:block"
    >
      <nav class="grid gap-1">
        <RouterLink
          v-for="item in sections"
          :key="item.key"
          :to="accountScopedRoute(item.routeName)"
          class="flex h-10 items-center gap-2 rounded-lg px-3 text-sm font-medium"
          :class="
            item.key === activeSection.key
              ? 'bg-n-blue-2 text-n-blue-11'
              : 'text-n-slate-12 hover:bg-n-alpha-2'
          "
        >
          <Icon :icon="item.icon" class="size-4" /><span class="truncate">{{
            item.label
          }}</span>
        </RouterLink>
      </nav>
    </aside>
    <section class="min-w-0 flex-1 overflow-auto">
      <header
        class="flex min-h-16 items-center justify-between border-b border-n-weak bg-n-solid-1 px-4 md:px-6"
      >
        <div>
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ activeSection.label }}
          </h1>
          <p class="text-sm text-n-slate-11">
            Changes apply to this account only.
          </p>
        </div>
        <button
          v-if="isQualification || isBooking"
          type="button"
          class="h-9 rounded-lg bg-n-brand px-4 text-sm font-medium text-white disabled:opacity-50"
          :disabled="saving || loading"
          @click="isQualification ? saveQualification() : saveBooking()"
        >
          {{ saving ? 'Saving...' : 'Save changes' }}
        </button>
      </header>
      <div v-if="loading" class="p-6 text-sm text-n-slate-11">
        Loading settings...
      </div>
      <article v-else class="max-w-4xl p-4 md:p-6">
        <template v-if="activeSection.key === 'offers_qualification'">
          <h2 class="text-base font-semibold text-n-slate-12">
            Qualification questions
          </h2>
          <div class="mt-3 grid gap-3">
            <label
              v-for="question in qualification.questions"
              :key="question.id"
              class="grid gap-1"
              ><span class="text-sm font-medium text-n-slate-12">{{
                question.signal
              }}</span
              ><input
                v-model="question.prompt"
                class="h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm"
                :disabled="!question.enabled"
            /></label>
          </div>
          <h2 class="mt-8 text-base font-semibold text-n-slate-12">
            Budget ranges
          </h2>
          <div class="mt-3 grid gap-3 sm:grid-cols-2">
            <label
              v-for="range in qualification.budget_ranges"
              :key="range.id"
              class="grid gap-1"
              ><span class="text-sm text-n-slate-11">{{ range.label }}</span
              ><input
                v-model.number="range.min_cents"
                type="number"
                min="0"
                class="h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm"
            /></label>
          </div>
        </template>
        <template v-else-if="activeSection.key === 'follow_ups'">
          <h2 class="text-base font-semibold text-n-slate-12">
            Incomplete-lead follow-ups
          </h2>
          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <label class="flex items-center gap-2 text-sm"
              ><input
                v-model="qualification.follow_up.enabled"
                type="checkbox"
              />
              Enabled</label
            ><label class="grid gap-1 text-sm"
              >Delay (minutes)<input
                v-model.number="qualification.follow_up.delay_minutes"
                type="number"
                min="1"
                class="h-10 rounded-lg border border-n-weak px-3" /></label
            ><label class="grid gap-1 text-sm"
              >Maximum attempts<input
                v-model.number="qualification.follow_up.max_attempts"
                type="number"
                min="0"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
          </div>
        </template>
        <template v-else-if="isBooking">
          <h2 class="text-base font-semibold text-n-slate-12">Availability</h2>
          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <label class="grid gap-1 text-sm"
              >Timezone<input
                v-model="booking.timezone"
                class="h-10 rounded-lg border border-n-weak px-3" /></label
            ><label class="grid gap-1 text-sm"
              >Meeting duration (minutes)<input
                v-model.number="booking.duration_minutes"
                type="number"
                min="15"
                class="h-10 rounded-lg border border-n-weak px-3" /></label
            ><label class="grid gap-1 text-sm"
              >Start time<input
                v-model="booking.allowed_hours.start"
                type="time"
                class="h-10 rounded-lg border border-n-weak px-3" /></label
            ><label class="grid gap-1 text-sm"
              >End time<input
                v-model="booking.allowed_hours.end"
                type="time"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
          </div>
        </template>
        <template v-else-if="nativeDestination">
          <h2 class="text-base font-semibold text-n-slate-12">
            Managed in workspace settings
          </h2>
          <p class="mt-2 text-sm text-n-slate-11">
            This uses the existing Chatwoot account configuration so
            assignments, alerts, and channels remain the same everywhere.
          </p>
          <RouterLink
            :to="accountScopedRoute(nativeDestination.route)"
            class="mt-5 inline-flex h-9 items-center rounded-lg bg-n-brand px-4 text-sm font-medium text-white"
          >
            {{ nativeDestination.label }}
          </RouterLink>
        </template>
      </article>
    </section>
  </main>
</template>
