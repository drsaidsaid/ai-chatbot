export const AI_LEAD_EMPLOYEE_TOP_LEVEL_NAVIGATION = [
  'Inbox',
  'Hot Leads',
  'Leads',
  'Reviews',
  'Knowledge',
  'Bookings',
  'Test Center',
  'Settings',
];

export const buildAILeadEmployeeMenuItems = ({
  t,
  accountScopedRoute,
  isAdmin = true,
}) => [
  {
    name: 'Inbox',
    label: t('SIDEBAR.INBOX'),
    icon: 'i-lucide-inbox',
    to: accountScopedRoute('inbox_view'),
    activeOn: ['inbox_view', 'inbox_view_conversation'],
    getterKeys: {
      count: 'notifications/getUnreadCount',
    },
  },
  {
    name: 'Hot Leads',
    label: t('AI_LEAD_EMPLOYEE.NAV.HOT_LEADS'),
    icon: 'i-lucide-flame',
    to: accountScopedRoute('owned_hot_leads_index'),
    activeOn: ['owned_hot_leads_index'],
  },
  {
    name: 'Leads',
    label: t('AI_LEAD_EMPLOYEE.NAV.LEADS'),
    icon: 'i-lucide-contact',
    to: accountScopedRoute('owned_leads_index'),
    activeOn: ['owned_leads_index'],
  },
  {
    name: 'Reviews',
    label: t('AI_LEAD_EMPLOYEE.NAV.REVIEWS'),
    icon: 'i-lucide-inbox',
    to: accountScopedRoute('owned_reviews_index'),
    activeOn: ['owned_reviews_index'],
  },
  {
    name: 'Knowledge',
    label: t('AI_LEAD_EMPLOYEE.NAV.KNOWLEDGE'),
    icon: 'i-lucide-book-open',
    to: accountScopedRoute('owned_knowledge_index'),
    activeOn: ['owned_knowledge_index'],
  },
  {
    name: 'Bookings',
    label: t('AI_LEAD_EMPLOYEE.NAV.BOOKINGS'),
    icon: 'i-lucide-calendar-check',
    to: accountScopedRoute('owned_bookings_index'),
    activeOn: ['owned_bookings_index'],
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
    label: t('SIDEBAR.SETTINGS'),
    icon: 'i-lucide-bolt',
    children: [
      ...(isAdmin
        ? [
            {
              name: 'Settings AI Provider',
              label: t('AI_LEAD_EMPLOYEE.NAV.AI_PROVIDER'),
              icon: 'i-lucide-brain-circuit',
              to: accountScopedRoute('owned_ai_provider_settings'),
            },
          ]
        : []),
      {
        name: 'Settings Account Settings',
        label: t('SIDEBAR.ACCOUNT_SETTINGS'),
        icon: 'i-lucide-briefcase',
        to: accountScopedRoute('general_settings_index'),
      },
      {
        name: 'Settings Agents',
        label: t('SIDEBAR.AGENTS'),
        icon: 'i-lucide-square-user',
        to: accountScopedRoute('agent_list'),
      },
      {
        name: 'Settings Teams',
        label: t('SIDEBAR.TEAMS'),
        icon: 'i-lucide-users',
        activeOn: [
          'settings_teams_list',
          'settings_teams_new',
          'settings_teams_finish',
          'settings_teams_add_agents',
          'settings_teams_show',
          'settings_teams_edit',
          'settings_teams_edit_members',
          'settings_teams_edit_finish',
        ],
        to: accountScopedRoute('settings_teams_list'),
      },
      {
        name: 'Settings Inboxes',
        label: t('SIDEBAR.INBOXES'),
        icon: 'i-lucide-inbox',
        activeOn: [
          'settings_inbox_list',
          'settings_inbox_show',
          'settings_inbox_new',
          'settings_inbox_finish',
          'settings_inboxes_page_channel',
          'settings_inboxes_add_agents',
        ],
        to: accountScopedRoute('settings_inbox_list'),
      },
      {
        name: 'Settings Templates',
        label: t('SIDEBAR.WHATSAPP_TEMPLATES'),
        icon: 'i-lucide-layout-template',
        to: accountScopedRoute('settings_templates'),
      },
    ],
  },
];
