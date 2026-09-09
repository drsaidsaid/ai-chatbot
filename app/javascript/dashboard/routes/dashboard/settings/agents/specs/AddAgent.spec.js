import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import AddAgent from '../AddAgent.vue';
import messages from 'dashboard/i18n/locale/en/agentMgmt.json';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

describe('Invite a Team Member', () => {
  it('explains assigned access, offers only fixed roles and submits a Team Member invitation', async () => {
    const create = vi.fn();
    const store = createStore({
      getters: {
        'agents/getUIFlags': () => ({}),
        'customRole/getCustomRoles': () => [{ id: 9, name: 'Custom scope' }],
      },
      actions: { 'agents/create': create },
    });
    const wrapper = mount(AddAgent, {
      global: {
        plugins: [
          store,
          createI18n({
            legacy: false,
            locale: 'en',
            messages: { en: messages },
          }),
        ],
        stubs: {
          WootModalHeader: {
            props: ['headerContent'],
            template: '<p>{{ headerContent }}</p>',
          },
        },
      },
    });
    expect(wrapper.findAll('option').map(option => option.text())).toEqual([
      'Admin',
      'Team Member',
    ]);
    expect(wrapper.text()).toContain('assigned');
    await wrapper.get('input').setValue('Asha Member');
    await wrapper.get('input[type="email"]').setValue('asha@example.test');
    await wrapper.get('form').trigger('submit.prevent');
    await flushPromises();
    expect(create).toHaveBeenCalledWith(expect.anything(), {
      name: 'Asha Member',
      email: 'asha@example.test',
      role: 'agent',
    });
    expect(wrapper.emitted('close')).toHaveLength(1);
  });
});
