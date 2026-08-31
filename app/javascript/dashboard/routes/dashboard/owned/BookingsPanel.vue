<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import bookingsAPI from 'dashboard/api/bookings';
import bookingConfigurationAPI from 'dashboard/api/bookingConfiguration';

const { t } = useI18n();
const bookings = ref([]);
const configuration = ref(null);
const slots = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const selectedSlot = ref('');
const conversationId = ref('');
const idempotencyKey = ref(`booking-${Date.now()}`);
const createStatus = ref(null);

const weekdayOptions = computed(() => [
  { value: 1, label: t('AI_LEAD_EMPLOYEE.BOOKINGS.WEEKDAY.MON') },
  { value: 2, label: t('AI_LEAD_EMPLOYEE.BOOKINGS.WEEKDAY.TUE') },
  { value: 3, label: t('AI_LEAD_EMPLOYEE.BOOKINGS.WEEKDAY.WED') },
  { value: 4, label: t('AI_LEAD_EMPLOYEE.BOOKINGS.WEEKDAY.THU') },
  { value: 5, label: t('AI_LEAD_EMPLOYEE.BOOKINGS.WEEKDAY.FRI') },
  { value: 6, label: t('AI_LEAD_EMPLOYEE.BOOKINGS.WEEKDAY.SAT') },
  { value: 0, label: t('AI_LEAD_EMPLOYEE.BOOKINGS.WEEKDAY.SUN') },
]);

const localDateTime = value => {
  if (!value) return '';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
};

const alertRecipientLabel = recipient => {
  if (typeof recipient === 'string') return recipient;

  return (
    recipient?.email ||
    recipient?.phone_number ||
    recipient?.phone ||
    recipient?.id?.toString() ||
    ''
  );
};

const bookingRows = computed(() =>
  bookings.value.map(booking => ({
    ...booking,
    local_start: localDateTime(booking.starts_at),
    local_end: localDateTime(booking.ends_at),
    invite: booking.calendar_invitation_sent_at
      ? t('AI_LEAD_EMPLOYEE.BOOKINGS.INVITE_SENT')
      : t('AI_LEAD_EMPLOYEE.BOOKINGS.NO_EMAIL'),
    alerts:
      booking.preparation_alert_recipients
        ?.map(alertRecipientLabel)
        .filter(Boolean)
        .join(', ') || t('AI_LEAD_EMPLOYEE.BOOKINGS.NONE'),
  }))
);

const loadBookings = async () => {
  const { data } = await bookingsAPI.get();
  bookings.value = data;
};

const loadConfiguration = async () => {
  const { data } = await bookingConfigurationAPI.get();
  configuration.value = {
    ...data,
    working_days: data.working_days || [],
    allowed_hours: data.allowed_hours || { start: '09:00', end: '17:00' },
  };
};

const loadSlots = async () => {
  const { data } = await bookingsAPI.availableSlots({ days: 7 });
  slots.value = data.slots || [];
  selectedSlot.value = slots.value[0] || '';
};

const load = async () => {
  isLoading.value = true;
  try {
    await Promise.all([loadConfiguration(), loadBookings()]);
    await loadSlots();
  } finally {
    isLoading.value = false;
  }
};

const toggleWorkingDay = day => {
  const days = new Set(configuration.value.working_days);
  if (days.has(day)) {
    days.delete(day);
  } else {
    days.add(day);
  }
  configuration.value.working_days = [...days].sort();
};

const saveConfiguration = async () => {
  isSaving.value = true;
  try {
    const { data } = await bookingConfigurationAPI.update(configuration.value);
    configuration.value = data;
    await loadSlots();
    useAlert(t('AI_LEAD_EMPLOYEE.BOOKINGS.SETTINGS_SAVED'));
  } finally {
    isSaving.value = false;
  }
};

const createBooking = async () => {
  createStatus.value = null;
  try {
    const { data } = await bookingsAPI.create({
      conversation_id: conversationId.value,
      starts_at: selectedSlot.value,
      idempotency_key: idempotencyKey.value,
    });
    createStatus.value = t('AI_LEAD_EMPLOYEE.BOOKINGS.CONFIRMED_FOR', {
      time: localDateTime(data.starts_at),
    });
    await Promise.all([loadBookings(), loadSlots()]);
  } catch (error) {
    createStatus.value =
      error.response?.status === 409
        ? t('AI_LEAD_EMPLOYEE.BOOKINGS.SLOT_UNAVAILABLE')
        : error.response?.data?.error ||
          t('AI_LEAD_EMPLOYEE.BOOKINGS.CREATE_ERROR');
  }
};

onMounted(load);
</script>

<template>
  <section
    class="mt-6 grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(320px,420px)]"
  >
    <div class="min-w-0 rounded-lg border border-n-weak bg-n-solid-1 p-5">
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.UPCOMING') }}
        </h2>
        <span class="text-xs text-n-slate-11">{{ bookingRows.length }}</span>
      </div>
      <div v-if="isLoading" class="mt-4 text-sm text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.LOADING') }}
      </div>
      <div v-else-if="!bookingRows.length" class="mt-4 text-sm text-n-slate-11">
        {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.EMPTY') }}
      </div>
      <div v-else class="mt-4 overflow-x-auto">
        <table class="min-w-full text-left text-sm">
          <thead class="text-xs uppercase text-n-slate-11">
            <tr>
              <th class="px-3 py-2 font-medium">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.LEAD') }}
              </th>
              <th class="px-3 py-2 font-medium">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.WHEN') }}
              </th>
              <th class="px-3 py-2 font-medium">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CONFIRMATION') }}
              </th>
              <th class="px-3 py-2 font-medium">
                {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.PREP_ALERT') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr v-for="booking in bookingRows" :key="booking.id">
              <td class="px-3 py-3 text-n-slate-12">
                {{
                  t('AI_LEAD_EMPLOYEE.BOOKINGS.LEAD_NUMBER', {
                    id: booking.contact_id,
                  })
                }}
              </td>
              <td class="px-3 py-3 text-n-slate-12">
                <div>{{ booking.local_start }}</div>
                <div class="text-xs text-n-slate-11">
                  {{ booking.local_end }}
                </div>
              </td>
              <td class="px-3 py-3 text-n-slate-12">
                <div>
                  {{
                    booking.confirmation_message_id
                      ? t('AI_LEAD_EMPLOYEE.BOOKINGS.WHATSAPP_SENT')
                      : t('AI_LEAD_EMPLOYEE.BOOKINGS.PENDING')
                  }}
                </div>
                <div class="text-xs text-n-slate-11">{{ booking.invite }}</div>
              </td>
              <td class="px-3 py-3 text-n-slate-12">{{ booking.alerts }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="configuration" class="flex min-w-0 flex-col gap-5">
      <form
        class="rounded-lg border border-n-weak bg-n-solid-1 p-5"
        @submit.prevent="saveConfiguration"
      >
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.SETTINGS') }}
        </h2>
        <label class="mt-4 flex items-center gap-2 text-sm text-n-slate-12">
          <input
            v-model="configuration.connected"
            type="checkbox"
            class="size-4"
          />
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CALENDAR_CONNECTED') }}
        </label>
        <label class="mt-4 block text-xs font-medium text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.TIMEZONE') }}
          <input
            v-model="configuration.timezone"
            class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
          />
        </label>
        <div class="mt-4 grid gap-3 sm:grid-cols-2">
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.START') }}
            <input
              v-model="configuration.allowed_hours.start"
              type="time"
              class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.END') }}
            <input
              v-model="configuration.allowed_hours.end"
              type="time"
              class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
        </div>
        <div class="mt-4 grid gap-3 sm:grid-cols-2">
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.DURATION') }}
            <input
              v-model.number="configuration.duration_minutes"
              type="number"
              min="15"
              step="15"
              class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.MINIMUM_NOTICE') }}
            <input
              v-model.number="configuration.minimum_notice_minutes"
              type="number"
              min="0"
              step="15"
              class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BUFFER_BEFORE') }}
            <input
              v-model.number="configuration.buffer_before_minutes"
              type="number"
              min="0"
              step="5"
              class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
          <label class="block text-xs font-medium text-n-slate-11">
            {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.BUFFER_AFTER') }}
            <input
              v-model.number="configuration.buffer_after_minutes"
              type="number"
              min="0"
              step="5"
              class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
        </div>
        <div class="mt-4 flex flex-wrap gap-2">
          <button
            v-for="day in weekdayOptions"
            :key="day.value"
            type="button"
            class="rounded border px-2 py-1 text-xs"
            :class="
              configuration.working_days.includes(day.value)
                ? 'border-n-brand bg-n-brand text-white'
                : 'border-n-weak text-n-slate-11'
            "
            @click="toggleWorkingDay(day.value)"
          >
            {{ day.label }}
          </button>
        </div>
        <button
          type="submit"
          class="mt-4 inline-flex h-8 items-center justify-center rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isSaving"
        >
          {{
            isSaving
              ? t('AI_LEAD_EMPLOYEE.BOOKINGS.SAVING')
              : t('AI_LEAD_EMPLOYEE.BOOKINGS.SAVE_SETTINGS')
          }}
        </button>
      </form>

      <form
        class="rounded-lg border border-n-weak bg-n-solid-1 p-5"
        @submit.prevent="createBooking"
      >
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CREATE') }}
        </h2>
        <label class="mt-4 block text-xs font-medium text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.AVAILABLE_SLOT') }}
          <select
            v-model="selectedSlot"
            class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
          >
            <option v-for="slot in slots" :key="slot" :value="slot">
              {{ localDateTime(slot) }}
            </option>
          </select>
        </label>
        <label class="mt-4 block text-xs font-medium text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.CONVERSATION_ID') }}
          <input
            v-model="conversationId"
            class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
          />
        </label>
        <label class="mt-4 block text-xs font-medium text-n-slate-11">
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.FIELD.RETRY_KEY') }}
          <input
            v-model="idempotencyKey"
            class="mt-1 w-full rounded border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
          />
        </label>
        <button
          type="submit"
          class="mt-4 inline-flex h-8 items-center justify-center rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="!selectedSlot || !conversationId"
        >
          {{ t('AI_LEAD_EMPLOYEE.BOOKINGS.CONFIRM_CALL') }}
        </button>
        <p v-if="createStatus" class="mt-3 text-sm text-n-slate-12">
          {{ createStatus }}
        </p>
      </form>
    </div>
  </section>
</template>
