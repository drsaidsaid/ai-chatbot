<script>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
export default {};
</script>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import BookingConfigurationAPI from 'dashboard/api/bookingConfiguration';
import QualificationConfigurationAPI from 'dashboard/api/qualificationConfiguration';
import OfferConfigurationPanel from './OfferConfigurationPanel.vue';

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
  buffer_before_minutes: 0,
  buffer_after_minutes: 0,
  exceptions: [],
  connection: null,
});
const weekdays = [
  ['Sun', 0],
  ['Mon', 1],
  ['Tue', 2],
  ['Wed', 3],
  ['Thu', 4],
  ['Fri', 5],
  ['Sat', 6],
];

const sections = computed(() => [
  {
    key: 'ai_provider',
    routeName: 'owned_ai_provider_settings',
    label: 'Managed AI',
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
const isQualification = computed(
  () => activeSection.value.key === 'follow_ups'
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
  if (activeSection.value.key === 'offers_qualification') {
    loading.value = false;
    return;
  }
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
const connectGoogle = async () => {
  try {
    const { data } = await BookingConfigurationAPI.connectGoogle();
    window.location.assign(data.authorization_url);
  } catch {
    useAlert('Unable to start Google Calendar connection.');
  }
};
const disconnectGoogle = async () => {
  try {
    const { data } = await BookingConfigurationAPI.disconnectGoogle();
    booking.connection = data;
    booking.connected = false;
    useAlert('Google Calendar disconnected.');
  } catch {
    useAlert('Unable to disconnect Google Calendar.');
  }
};
const addException = () =>
  booking.exceptions.push({ date: '', unavailable: true });
watch(() => props.section, load);
onMounted(load);
</script>

<template>
  <main class="flex h-full min-w-0 flex-1 bg-n-background">
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
          class="min-h-10 shrink-0 whitespace-nowrap rounded-lg bg-n-brand px-4 text-sm font-medium text-white disabled:opacity-50"
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
        <OfferConfigurationPanel
          v-if="activeSection.key === 'offers_qualification'"
        />
        <template v-else-if="activeSection.key === 'follow_ups'">
          <h2 class="text-base font-semibold text-n-slate-12">
            Incomplete-lead follow-ups
          </h2>
          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <label class="flex items-center gap-2 text-sm">
              <input
                v-model="qualification.follow_up.enabled"
                type="checkbox"
              />
              <span>Enabled</span>
            </label>
            <label class="grid gap-1 text-sm">
              <span>Delay (minutes)</span>
              <input
                v-model.number="qualification.follow_up.delay_minutes"
                type="number"
                min="1"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
            <label class="grid gap-1 text-sm">
              <span>Maximum attempts</span>
              <input
                v-model.number="qualification.follow_up.max_attempts"
                type="number"
                min="0"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
          </div>
        </template>
        <template v-else-if="isBooking">
          <div class="rounded-xl border border-n-weak bg-n-solid-2 p-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 class="text-base font-semibold text-n-slate-12">
                  Google Calendar
                </h2>
                <p class="text-sm text-n-slate-11">
                  {{
                    booking.connected
                      ? `Connected to ${booking.connection?.calendar_id || booking.calendar_id}`
                      : 'Connect a calendar before offering times.'
                  }}
                </p>
                <p
                  v-if="booking.connection?.last_error_code"
                  class="mt-1 text-sm text-n-ruby-11"
                >
                  Calendar access needs attention:
                  {{ booking.connection.last_error_code }}. Reconnect to restore
                  booking.
                </p>
              </div>
              <button
                type="button"
                class="h-10 rounded-lg border border-n-weak px-4 text-sm font-medium"
                @click="
                  booking.connected ? disconnectGoogle() : connectGoogle()
                "
              >
                {{
                  booking.connected ? 'Disconnect' : 'Connect Google Calendar'
                }}
              </button>
            </div>
          </div>
          <h2 class="mt-6 text-base font-semibold text-n-slate-12">
            Availability
          </h2>
          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <label class="grid gap-1 text-sm">
              <span>Google Calendar ID</span>
              <input
                v-model="booking.calendar_id"
                placeholder="primary"
                class="h-10 rounded-lg border border-n-weak px-3"
              />
            </label>
            <label class="grid gap-1 text-sm">
              <span>Timezone</span>
              <input
                v-model="booking.timezone"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
            <label class="grid gap-1 text-sm">
              <span>Meeting duration (minutes)</span>
              <input
                v-model.number="booking.duration_minutes"
                type="number"
                min="15"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
            <label class="grid gap-1 text-sm">
              <span>Start time</span>
              <input
                v-model="booking.allowed_hours.start"
                type="time"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
            <label class="grid gap-1 text-sm">
              <span>End time</span>
              <input
                v-model="booking.allowed_hours.end"
                type="time"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
            <label class="grid gap-1 text-sm"
              ><span>Buffer before (minutes)</span
              ><input
                v-model.number="booking.buffer_before_minutes"
                type="number"
                min="0"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
            <label class="grid gap-1 text-sm"
              ><span>Buffer after (minutes)</span
              ><input
                v-model.number="booking.buffer_after_minutes"
                type="number"
                min="0"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
            <label class="grid gap-1 text-sm"
              ><span>Minimum notice (minutes)</span
              ><input
                v-model.number="booking.minimum_notice_minutes"
                type="number"
                min="0"
                class="h-10 rounded-lg border border-n-weak px-3"
            /></label>
          </div>
          <fieldset class="mt-5">
            <legend class="text-sm font-medium text-n-slate-12">
              Available weekdays
            </legend>
            <div class="mt-2 flex flex-wrap gap-3">
              <label
                v-for="[label, day] in weekdays"
                :key="day"
                class="flex items-center gap-2 text-sm"
              >
                <input
                  v-model="booking.working_days"
                  type="checkbox"
                  :value="day"
                />{{ label }}
              </label>
            </div>
          </fieldset>
          <div class="mt-5">
            <div class="flex items-center justify-between">
              <h3 class="text-sm font-medium text-n-slate-12">
                Unavailable dates
              </h3>
              <button
                type="button"
                class="text-sm font-medium text-n-brand"
                @click="addException"
              >
                Add date
              </button>
            </div>
            <div
              v-for="(exception, index) in booking.exceptions"
              :key="index"
              class="mt-2 flex gap-2"
            >
              <input
                v-model="exception.date"
                type="date"
                class="h-10 rounded-lg border border-n-weak px-3"
              />
              <button
                type="button"
                class="text-sm text-n-ruby-11"
                @click="booking.exceptions.splice(index, 1)"
              >
                Remove
              </button>
            </div>
          </div>
          <p class="mt-5 rounded-lg bg-n-alpha-2 p-3 text-sm text-n-slate-11">
            Preview: {{ booking.working_days.length }} days each week,
            {{ booking.allowed_hours.start }}–{{ booking.allowed_hours.end }}
            {{ booking.timezone }}, {{ booking.duration_minutes }} minute calls.
          </p>
        </template>
        <template v-else-if="nativeDestination">
          <h2 class="text-base font-semibold text-n-slate-12">
            Managed in workspace settings
          </h2>
          <p class="mt-2 text-sm text-n-slate-11">
            This uses the Business Account configuration so assignments, alerts,
            and channels remain the same everywhere.
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
