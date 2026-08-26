export const AI_LEAD_EMPLOYEE_TOP_LEVEL_NAVIGATION = [
  'Inbox',
  'Leads',
  'Bookings',
  'Knowledge',
  'Test Center',
  'Settings',
];

export const AI_LEAD_EMPLOYEE_MOBILE_NAVIGATION = [
  'Inbox',
  'Leads',
  'Bookings',
  'More',
];

export const AI_LEAD_EMPLOYEE_MORE_NAVIGATION = [
  'Knowledge',
  'Test Center',
  'Settings',
];

export const AI_LEAD_EMPLOYEE_SETTINGS_ROUTE_NAMES = [
  'ai_lead_employee_settings_index',
  'ai_lead_employee_settings_offers_qualification',
  'ai_lead_employee_settings_booking_business_hours',
  'ai_lead_employee_settings_team_assignment',
  'ai_lead_employee_settings_follow_ups',
  'ai_lead_employee_settings_alerts',
  'ai_lead_employee_settings_whatsapp_connection',
  'owned_ai_provider_settings',
];

export const CONVERSATION_COCKPIT_QUEUE_KEYS = ['hot', 'review', 'booked'];

export const queueRouteQuery = queue => ({ queue });

export const conversationCockpitQueueFilters = {
  hot: { quality: 'highly_qualified' },
  review: { unanswered: 'true' },
  booked: { booking_status: 'booked' },
};

export const isConversationCockpitQueue = queue =>
  CONVERSATION_COCKPIT_QUEUE_KEYS.includes(queue);

export const conversationMatchesCockpitQueue = (conversation, queue) => {
  if (!isConversationCockpitQueue(queue)) return true;

  const customAttributes = conversation?.custom_attributes || {};
  if (queue === 'hot') {
    return customAttributes.lead_quality === 'highly_qualified';
  }

  if (queue === 'review') {
    return (
      customAttributes.follow_up_state === 'human_review' ||
      Number(customAttributes.unanswered_questions_count || 0) > 0
    );
  }

  return (
    customAttributes.booking_state === 'booked' ||
    customAttributes.follow_up_state === 'call_booked'
  );
};

export const buildAILeadEmployeeMenuItems = ({ t, accountScopedRoute }) => [
  {
    name: 'Inbox',
    label: t('AI_LEAD_EMPLOYEE.NAV.INBOX'),
    icon: 'i-lucide-message-circle',
    to: accountScopedRoute('home'),
    activeOn: [
      'home',
      'inbox_conversation',
      'inbox_dashboard',
      'conversation_through_inbox',
      'label_conversations',
      'conversations_through_label',
      'team_conversations',
      'conversations_through_team',
      'folder_conversations',
      'conversations_through_folders',
      'conversation_mentions',
      'conversation_through_mentions',
      'conversation_unattended',
      'conversation_through_unattended',
      'conversation_participating',
      'conversation_through_participating',
      'inbox_view',
      'inbox_view_conversation',
    ],
    getterKeys: {
      count: 'notifications/getUnreadCount',
    },
  },
  {
    name: 'Leads',
    label: t('AI_LEAD_EMPLOYEE.NAV.LEADS'),
    icon: 'i-lucide-users',
    to: accountScopedRoute('owned_leads_index'),
    activeOn: ['owned_leads_index'],
  },
  {
    name: 'Bookings',
    label: t('AI_LEAD_EMPLOYEE.NAV.BOOKINGS'),
    icon: 'i-lucide-calendar-days',
    to: accountScopedRoute('owned_bookings_index'),
    activeOn: ['owned_bookings_index'],
  },
  {
    name: 'Knowledge',
    label: t('AI_LEAD_EMPLOYEE.NAV.KNOWLEDGE'),
    icon: 'i-lucide-book-open',
    to: accountScopedRoute('owned_knowledge_index'),
    activeOn: ['owned_knowledge_index'],
  },
  {
    name: 'Test Center',
    label: t('AI_LEAD_EMPLOYEE.NAV.TEST_CENTER'),
    icon: 'i-lucide-clipboard-check',
    to: accountScopedRoute('owned_test_center_index'),
    activeOn: ['owned_test_center_index'],
  },
  {
    name: 'Settings',
    label: t('AI_LEAD_EMPLOYEE.NAV.SETTINGS'),
    icon: 'i-lucide-settings',
    to: accountScopedRoute('ai_lead_employee_settings_offers_qualification'),
    activeOn: AI_LEAD_EMPLOYEE_SETTINGS_ROUTE_NAMES,
  },
];

export const buildAILeadEmployeeMobileNavItems = ({
  t,
  accountScopedRoute,
}) => [
  {
    name: 'Inbox',
    label: t('AI_LEAD_EMPLOYEE.NAV.INBOX'),
    icon: 'i-lucide-message-circle',
    to: accountScopedRoute('home'),
    activeOn: [
      'home',
      'inbox_conversation',
      'inbox_dashboard',
      'conversation_through_inbox',
      'inbox_view',
      'inbox_view_conversation',
    ],
  },
  {
    name: 'Leads',
    label: t('AI_LEAD_EMPLOYEE.NAV.LEADS'),
    icon: 'i-lucide-users',
    to: accountScopedRoute('owned_leads_index'),
    activeOn: ['owned_leads_index'],
  },
  {
    name: 'Bookings',
    label: t('AI_LEAD_EMPLOYEE.NAV.BOOKINGS'),
    icon: 'i-lucide-calendar-days',
    to: accountScopedRoute('owned_bookings_index'),
    activeOn: ['owned_bookings_index'],
  },
];

export const buildAILeadEmployeeMoreNavItems = ({ t, accountScopedRoute }) => [
  {
    name: 'Knowledge',
    label: t('AI_LEAD_EMPLOYEE.NAV.KNOWLEDGE'),
    icon: 'i-lucide-book-open',
    to: accountScopedRoute('owned_knowledge_index'),
    activeOn: ['owned_knowledge_index'],
  },
  {
    name: 'Test Center',
    label: t('AI_LEAD_EMPLOYEE.NAV.TEST_CENTER'),
    icon: 'i-lucide-flask-conical',
    to: accountScopedRoute('owned_test_center_index'),
    activeOn: ['owned_test_center_index'],
  },
  {
    name: 'Settings',
    label: t('AI_LEAD_EMPLOYEE.NAV.SETTINGS'),
    icon: 'i-lucide-settings',
    to: accountScopedRoute('ai_lead_employee_settings_offers_qualification'),
    activeOn: AI_LEAD_EMPLOYEE_SETTINGS_ROUTE_NAMES,
  },
];
