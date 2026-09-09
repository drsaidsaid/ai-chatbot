# Source verification

These excerpts support current-run browser findings. Source commit: `74d156e327e3ddb2deedd1503c6d1c04b0b1359e`. They are supporting evidence, not substitutes for the screenshots. Line numbers refer to this release candidate.

## Inbox navigation, actions and mobile controls

File: `app/javascript/dashboard/routes/dashboard/conversation/InboxConversationCockpit.vue`
SHA-256: `01cfb506f433186dfd6cd8099974abffd7278e939046aaec40bb07cfa933a3e2`

```text
298: const canPauseAI = computed(
299:   () =>
300:     currentChat.value?.control_state === 'ai_active' && !isUpdatingAction.value
301: );
302: const canResumeAI = computed(
303:   () =>
304:     currentChat.value?.control_state &&
305:     currentChat.value.control_state !== 'ai_active' &&
306:     !['human_active', 'closed'].includes(currentChat.value.control_state) &&
307:     !isUpdatingAction.value
308: );
```

```text
447: const confirmCallTime = async () => {
448:   if (!currentChat.value?.id || isUpdatingAction.value) return;
449:
450:   isUpdatingAction.value = true;
451:   try {
452:     const startsAt =
453:       latestBooking.value?.starts_at ||
454:       new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
455:     await BookingsAPI.create({
456:       conversation_id: currentChat.value.id,
457:       starts_at: startsAt,
458:       idempotency_key: `cockpit-${currentChat.value.id}-${startsAt}`,
459:     });
460:     useAlert(t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CALL_CONFIRMED'));
461:     await loadDashboard();
```

```text
504:     class="flex h-full min-h-0 w-full overflow-hidden bg-n-background text-n-slate-12"
505:     data-testid="inbox-conversation-cockpit"
506:   >
507:     <aside
508:       class="hidden h-full w-[304px] shrink-0 flex-col border-r border-n-weak bg-n-surface-1 lg:flex 2xl:w-[320px]"
509:       :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.INBOX_CONVERSATIONS')"
510:     >
511:       <header class="border-b border-n-weak px-3 py-3">
```

```text
740:       <header
741:         v-if="currentChat.id"
742:         class="flex min-h-[72px] shrink-0 items-center gap-3 border-b border-n-weak bg-n-background px-4 lg:min-h-[82px]"
743:       >
744:         <button
745:           type="button"
746:           class="grid size-10 place-items-center rounded-lg text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand lg:hidden"
747:           :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.BACK_TO_LIST')"
748:           @click="
749:             router.push({
750:               name: 'home',
751:               params: route.params,
752:               query: route.query,
753:             })
754:           "
755:         >
756:           <Icon icon="i-lucide-arrow-left" class="size-5" />
757:         </button>
758:         <Avatar
759:           :name="selectedContact.name"
```

```text
839:           </div>
840:           <button
841:             type="button"
842:             class="grid size-9 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
843:             :aria-label="t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.MORE_ACTIONS')"
844:           >
845:             <Icon icon="i-lucide-more-vertical" class="size-5" />
846:           </button>
847:         </div>
```

```text
1034:               </div>
1035:               <div
1036:                 class="mt-3 grid gap-3 text-xs text-n-slate-11 md:grid-cols-3"
1037:               >
1038:                 <div>
1039:                   <div class="font-medium text-n-slate-12">
1040:                     {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PROPOSED_TIME') }}
1041:                   </div>
1042:                   <div>
1043:                     {{
1044:                       latestBooking
1045:                         ? formatTime(latestBooking.starts_at)
1046:                         : nextAction.detail
1047:                     }}
1048:                   </div>
1049:                 </div>
1050:                 <div>
1051:                   <div class="font-medium text-n-slate-12">
1052:                     {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.ATTENDEE') }}
1053:                   </div>
1054:                   <div>{{ selectedContact.name }} {{ phoneNumber }}</div>
1055:                 </div>
1056:                 <div>
1057:                   <div class="font-medium text-n-slate-12">
1058:                     {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CALL_TYPE') }}
1059:                   </div>
1060:                   <div>
1061:                     {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.PRODUCT_DEMO') }}
1062:                   </div>
1063:                 </div>
1064:               </div>
1065:               <div class="mt-3 flex flex-wrap justify-end gap-2">
1066:                 <RouterLink
1067:                   :to="accountScopedRoute('owned_knowledge_index')"
1068:                   class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
1069:                 >
1070:                   {{ t('AI_LEAD_EMPLOYEE.NAV.KNOWLEDGE') }}
1071:                   <Icon icon="i-lucide-external-link" class="size-4" />
1072:                 </RouterLink>
1073:                 <RouterLink
1074:                   :to="accountScopedRoute('owned_test_center_index')"
1075:                   class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
1076:                 >
1077:                   {{ t('AI_LEAD_EMPLOYEE.NAV.TEST_CENTER') }}
1078:                   <Icon icon="i-lucide-external-link" class="size-4" />
1079:                 </RouterLink>
1080:                 <button
1081:                   type="button"
1082:                   class="inline-flex h-9 items-center gap-2 rounded-lg bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
1083:                   :disabled="isUpdatingAction"
1084:                   @click="confirmCallTime"
1085:                 >
1086:                   {{ t('AI_LEAD_EMPLOYEE.INBOX_COCKPIT.CONFIRM_CALL') }}
1087:                 </button>
1088:                 <button
1089:                   type="button"
1090:                   class="inline-flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-60"
```

## Lead row keyboard behavior

File: `app/javascript/dashboard/routes/dashboard/owned/LeadsDirectoryPage.vue`
SHA-256: `fa1b6b843beba5e3e406f2fd3032f07b1d9f2f89548a4c9e74db810289e0411e`

```text
910:               <template v-else>
911:                 <tr
912:                   v-for="lead in leads"
913:                   :key="lead.id"
914:                   class="h-[58px] cursor-pointer hover:bg-n-alpha-2"
915:                   :class="selectedLead?.id === lead.id ? 'bg-n-blue-2' : ''"
916:                   @click="selectLead(lead)"
917:                 >
918:                   <td class="px-3 py-2">
919:                     <input
920:                       type="checkbox"
921:                       class="rounded border-n-weak"
922:                       :checked="isLeadBulkSelected(lead)"
923:                       :aria-label="
924:                         t('AI_LEAD_EMPLOYEE.LEADS.SELECT_ROW', {
925:                           name: lead.name,
926:                         })
927:                       "
928:                       @click.stop="toggleLeadBulkSelection(lead)"
929:                     />
930:                   </td>
931:                   <td class="min-w-0 px-3 py-2">
932:                     <div class="flex min-w-0 items-center gap-2">
933:                       <span
934:                         class="grid size-8 shrink-0 place-items-center rounded-full bg-n-slate-3 text-xs font-medium text-n-slate-12"
```

## Settings navigation and stored money units

File: `app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/AiLeadEmployeeSettingsShell.vue`
SHA-256: `80428b95257c12947f909a67d536f8d692c89cee53b98502d217f12f8864262d`

```text
140: watch(() => props.section, load);
141: onMounted(load);
142: </script>
143:
144: <template>
145:   <main class="flex h-full min-w-0 flex-1 bg-n-background">
146:     <aside
147:       class="hidden w-64 shrink-0 border-r border-n-weak bg-n-solid-1 p-4 md:block"
148:     >
149:       <nav class="grid gap-1">
150:         <RouterLink
151:           v-for="item in sections"
152:           :key="item.key"
153:           :to="accountScopedRoute(item.routeName)"
154:           class="flex h-10 items-center gap-2 rounded-lg px-3 text-sm font-medium"
```

```text
212:             Budget ranges
213:           </h2>
214:           <div class="mt-3 grid gap-3 sm:grid-cols-2">
215:             <label
216:               v-for="range in qualification.budget_ranges"
217:               :key="range.id"
218:               class="grid gap-1"
219:               ><span class="text-sm text-n-slate-11">{{ range.label }}</span
220:               ><input
221:                 v-model.number="range.min_cents"
222:                 type="number"
223:                 min="0"
224:                 class="h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm"
225:             /></label>
226:           </div>
227:         </template>
```
