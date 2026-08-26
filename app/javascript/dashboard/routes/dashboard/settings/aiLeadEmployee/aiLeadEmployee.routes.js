import { frontendURL } from 'dashboard/helper/URLHelper';
import AiLeadEmployeeSettingsShell from './AiLeadEmployeeSettingsShell.vue';

const ADMIN_PERMISSIONS = ['administrator'];

const aiLeadEmployeeSettingsRoute = ({ path, name, section }) => ({
  path: frontendURL(`accounts/:accountId/settings/ai-lead-employee/${path}`),
  name,
  component: AiLeadEmployeeSettingsShell,
  props: { section },
  meta: {
    permissions: ADMIN_PERMISSIONS,
  },
});

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-lead-employee'),
      name: 'ai_lead_employee_settings_index',
      redirect: to => ({
        name: 'ai_lead_employee_settings_offers_qualification',
        params: to.params,
      }),
      meta: {
        permissions: ADMIN_PERMISSIONS,
      },
    },
    aiLeadEmployeeSettingsRoute({
      path: 'offers-qualification',
      name: 'ai_lead_employee_settings_offers_qualification',
      section: 'offers_qualification',
    }),
    aiLeadEmployeeSettingsRoute({
      path: 'booking-business-hours',
      name: 'ai_lead_employee_settings_booking_business_hours',
      section: 'booking_business_hours',
    }),
    aiLeadEmployeeSettingsRoute({
      path: 'team-assignment',
      name: 'ai_lead_employee_settings_team_assignment',
      section: 'team_assignment',
    }),
    aiLeadEmployeeSettingsRoute({
      path: 'follow-ups',
      name: 'ai_lead_employee_settings_follow_ups',
      section: 'follow_ups',
    }),
    aiLeadEmployeeSettingsRoute({
      path: 'alerts',
      name: 'ai_lead_employee_settings_alerts',
      section: 'alerts',
    }),
    aiLeadEmployeeSettingsRoute({
      path: 'whatsapp-connection',
      name: 'ai_lead_employee_settings_whatsapp_connection',
      section: 'whatsapp_connection',
    }),
  ],
};
