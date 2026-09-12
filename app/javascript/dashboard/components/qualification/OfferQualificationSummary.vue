<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  qualification: { type: Object, required: true },
  showOutcome: { type: Boolean, default: true },
});
const { t } = useI18n();
const label = key => t(`AI_LEAD_EMPLOYEE.OFFERS.${key}`);
const selectedOffer = computed(() =>
  props.qualification.offers?.find(
    offer => offer.id === props.qualification.offer_id
  )
);
const humanize = value => String(value || '').replaceAll('_', ' ');
const fieldLabel = key =>
  props.qualification.fields?.find(field => field.key === key)?.meaning ||
  humanize(key);
const evidenceValue = record =>
  record.value ?? record.normalized_value?.value ?? label('UNKNOWN');
const polarity = record => record.normalized_value?.polarity || 'unknown';
const safeSourcePath = record =>
  /^\/app\/accounts\/\d+\/conversations\/\d+(\?messageId=\d+)?$/.test(
    record.source_path || ''
  )
    ? record.source_path
    : null;
</script>

<template>
  <section
    class="grid gap-3 text-sm text-n-slate-12"
    data-testid="offer-qualification-summary"
  >
    <h3 class="font-semibold">
      {{ selectedOffer?.name || label('CHOOSE') }}
    </h3>
    <p v-if="qualification.selection_required" class="text-n-slate-11">
      {{ label('SELECT_HELP') }}
    </p>
    <template v-else>
      <p v-if="selectedOffer && !selectedOffer.enabled" class="text-n-amber-11">
        {{ label('DISABLED') }}
      </p>
      <div class="grid gap-1 text-xs text-n-slate-11">
        <span v-if="qualification.configuration_version">
          {{
            t('AI_LEAD_EMPLOYEE.OFFERS.EVALUATED_REVISION', {
              version: qualification.configuration_version,
            })
          }}
        </span>
        <span v-else>
          {{ label('NOT_EVALUATED') }}
        </span>
        <span v-if="qualification.current_configuration_version">
          {{
            t('AI_LEAD_EMPLOYEE.OFFERS.CURRENT_REVISION', {
              version: qualification.current_configuration_version,
            })
          }}
        </span>
      </div>
      <p
        v-if="qualification.stale_at"
        role="status"
        class="rounded-lg bg-n-amber-2 p-3 text-n-amber-11"
      >
        {{ label('STALE') }}
      </p>
      <template v-if="showOutcome">
        <p>
          {{
            [humanize(qualification.quality), qualification.score ?? 0].join(
              ' · '
            )
          }}
        </p>
        <ul
          v-if="qualification.reasons?.length"
          class="list-disc space-y-1 pl-4"
        >
          <li v-for="reason in qualification.reasons" :key="reason">
            {{ reason }}
          </li>
        </ul>
        <p v-if="qualification.next_question && !qualification.stale_at">
          <strong> {{ label('NEXT_QUESTION') }} </strong><br />
          {{ qualification.next_question }}
        </p>
      </template>
      <div v-if="qualification.missing_signals?.length">
        <h4 class="font-medium">
          {{ label('MISSING') }}
        </h4>
        <p>
          {{ qualification.missing_signals.map(fieldLabel).join(', ') }}
        </p>
      </div>
      <div class="grid gap-2">
        <h4 class="font-medium">
          {{ label('EVIDENCE_HISTORY') }}
        </h4>
        <p
          v-if="!qualification.evidence_records?.length"
          class="text-n-slate-11"
        >
          {{ label('NO_EVIDENCE') }}
        </p>
        <article
          v-for="record in qualification.evidence_records"
          :key="record.id"
          class="grid gap-1 rounded-lg border border-n-weak p-3"
        >
          <div class="flex flex-wrap justify-between gap-2">
            <strong>
              {{ fieldLabel(record.field_key || record.signal) }}
            </strong>
            <span
              class="text-xs"
              :class="
                polarity(record) === 'negative'
                  ? 'text-n-ruby-11'
                  : 'text-n-slate-11'
              "
            >
              {{ label(polarity(record).toUpperCase()) }}
            </span>
          </div>
          <p class="break-words">
            {{ evidenceValue(record) }}
          </p>
          <span v-if="record.superseded" class="text-xs text-n-amber-11">
            {{ label('SUPERSEDED') }}
          </span>
          <a
            v-if="safeSourcePath(record)"
            :href="safeSourcePath(record)"
            class="text-xs text-n-blue-11 underline"
          >
            {{
              label(
                record.source_reference?.type === 'human_edit'
                  ? 'HUMAN_EDIT'
                  : 'SOURCE_MESSAGE'
              )
            }}
          </a>
          <span v-else class="text-xs text-n-slate-11">
            {{
              label(record.source === 'human' ? 'HUMAN_EDIT' : 'SOURCE_MESSAGE')
            }}
          </span>
          <time
            v-if="record.observed_at"
            :datetime="record.observed_at"
            class="text-xs text-n-slate-11"
          >
            {{ new Date(record.observed_at).toLocaleString() }}
          </time>
        </article>
      </div>
    </template>
    <details
      v-if="qualification.legacy_qualification"
      class="rounded-lg border border-n-weak p-3 text-n-slate-11"
    >
      <summary>
        {{ label('LEGACY') }}
      </summary>
      <p class="mt-2">
        {{
          [
            humanize(qualification.legacy_qualification.quality),
            qualification.legacy_qualification.score,
          ].join(' · ')
        }}
      </p>
      <p
        v-for="reason in qualification.legacy_qualification.reasons"
        :key="reason"
      >
        {{ reason }}
      </p>
    </details>
  </section>
</template>
