// Keep CE routes in source while exposing only the owned V1 workflows.
export const isSupportedV1Route = route => {
  if (!route.path) return true;
  const match = route.path.match(/^\/app\/accounts\/[^/]+\/(.*)/);
  if (!match) return true;
  const path = match[1];
  if (path.startsWith('settings/')) {
    if (route.name === 'settings_inboxes_page_channel') {
      return route.params.sub_page === 'whatsapp';
    }
    return /^(settings\/(ai-lead-employee|ai-provider|general|agents|teams|inboxes))(\/|$)/.test(
      path
    );
  }
  return /^(dashboard|conversations|inbox|inbox-view|leads|bookings|knowledge|reviews|hot-leads|test-center|profile|unavailable|suspended|onboarding|mentions|unattended|participating|label|team|custom_view)(\/|$)/.test(
    path
  );
};
