import { computed, defineComponent } from 'vue';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import { createRouter, createMemoryHistory } from 'vue-router';
import VueDOMPurifyHTML from 'vue-dompurify-html';
import { domPurifyConfig } from 'shared/helpers/HTMLSanitizer.js';
import conversation from 'dashboard/i18n/locale/en/conversation.json';
import MessageList from '../MessageList.vue';
import Message from '../Message.vue';
import MessageMeta from '../MessageMeta.vue';
import chatlist from 'dashboard/i18n/locale/en/chatlist.json';
import { mutations } from 'dashboard/store/modules/conversations';
import actions from 'dashboard/store/modules/conversations/actions';
import createdOrdering from './fixtures/whatsappCreatedOrdering.json';

const wrappers = [];
const mountMessages = async messages => {
  const inbox = { id: 1, channel_type: 'Channel::Whatsapp' };
  const store = createStore({
    state: {
      selectedChatId: 1,
      allConversations: [{ id: 1, inbox_id: 1, messages }],
    },
    mutations,
    actions: {
      addMessage: actions.addMessage,
      updateMessage: actions.updateMessage,
    },
    getters: {
      getSelectedChat: state => state.allConversations[0],
      'inboxes/getInboxById': () => () => inbox,
      'inboxes/getInbox': () => () => inbox,
      getSelectedChatAttachments: () => [],
      'globalConfig/get': () => ({}),
    },
  });
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/', component: { template: '<div />' } }],
  });
  await router.push('/');
  await router.isReady();
  const Host = defineComponent({
    components: { MessageList },
    setup: () => ({
      messages: computed(() => store.state.allConversations[0].messages),
    }),
    template: '<MessageList :messages="messages" :current-user-id="1" />',
  });
  const wrapper = mount(Host, {
    global: {
      plugins: [
        [VueDOMPurifyHTML, domPurifyConfig],
        store,
        router,
        createI18n({
          legacy: false,
          locale: 'en',
          messages: { en: { ...chatlist, ...conversation } },
        }),
      ],
      directives: { tooltip: () => {} },
      stubs: { ContextMenu: true },
    },
  });
  wrappers.push(wrapper);
  return wrapper;
};
const reply = (id, state) => ({
  id,
  content: `Operator reply ${id}`,
  status: 'sent',
  source_id: state === 'accepted' ? `wamid.${id}` : null,
  created_at: Math.floor(Date.now() / 60000) * 60,
  message_type: 1,
  sender: { id: 1, type: 'user', name: 'Operator' },
  sender_id: 1,
  conversation_id: 1,
  private: false,
  content_attributes: state ? { whatsapp_delivery: { state } } : {},
});
afterEach(() => wrappers.splice(0).forEach(wrapper => wrapper.unmount()));

describe('WhatsApp outcomes in the actual grouped MessageList', () => {
  it.each([
    ['pending', 'Pending'],
    ['claimed', 'Sending'],
    ['dispatching', 'Sending'],
    ['unknown', 'Delivery unknown'],
    ['canceled', 'Canceled'],
    ['accepted', 'Accepted by WhatsApp; awaiting delivery'],
  ])(
    'keeps each %s reply outcome visible before the next same-minute reply',
    async (state, label) => {
      const wrapper = await mountMessages([
        reply(1, state),
        reply(2, 'accepted'),
      ]);
      expect(wrapper.findAllComponents(Message)).toHaveLength(2);
      expect(wrapper.text()).toContain('Operator reply 1');
      const first = wrapper.find('#message1');
      expect(first.findComponent(MessageMeta).exists()).toBe(true);
      expect(first.find('[role="status"]').text()).toBe(label);
      expect(first.find('button[aria-label="Retry delivery"]').exists()).toBe(
        false
      );
    }
  );

  it.each(createdOrdering)(
    '$case remains visible when the original creation reaches the real store after its outcome',
    async ({
      case: outcome,
      pending_creation: pending,
      updated,
      late_creation: created,
    }) => {
      const identity = reply(1, 'pending');
      const initial = { ...identity, ...pending };
      const wrapper = await mountMessages([initial]);
      const store = wrapper.vm.$store;
      await store.dispatch('updateMessage', { ...identity, ...updated });
      const label =
        outcome === 'accepted'
          ? 'Accepted by WhatsApp; awaiting delivery'
          : 'Delivery unknown';
      expect(wrapper.find('#message1 [role="status"]').text()).toBe(label);
      await store.dispatch('addMessage', { ...identity, ...created });
      expect(wrapper.find('#message1 [role="status"]').text()).toBe(label);
      expect(store.state.allConversations[0].messages).toHaveLength(1);
      expect(store.state.allConversations[0].messages[0]).toMatchObject({
        echo_id: pending.echo_id,
        source_id: updated.source_id,
      });
      expect(wrapper.find('button[aria-label="Retry delivery"]').exists()).toBe(
        false
      );
    }
  );

  it.each(
    createdOrdering.flatMap(fixture =>
      [false, true].map(updateFirst => ({ ...fixture, updateFirst }))
    )
  )(
    '$case creation reconciles the optimistic reply when updateFirst=$updateFirst',
    async ({
      case: outcome,
      pending_creation: pending,
      updated,
      late_creation: created,
      updateFirst,
    }) => {
      const identity = reply(1, 'pending');
      const unrelated = { ...reply(2, 'pending'), content: identity.content };
      const wrapper = await mountMessages([
        { ...identity, id: pending.echo_id, status: 'progress' },
        unrelated,
      ]);
      const store = wrapper.vm.$store;
      if (updateFirst) {
        await store.dispatch('updateMessage', { ...identity, ...updated });
      }
      await store.dispatch('addMessage', {
        ...identity,
        ...created,
      });
      expect(store.state.allConversations[0].messages).toHaveLength(2);
      expect(store.state.allConversations[0].messages[0]).toMatchObject({
        id: 1,
        echo_id: pending.echo_id,
        source_id: created.source_id,
      });
      expect(store.state.allConversations[0].messages[1]).toEqual(unrelated);
      expect(wrapper.findAll('[data-message-id="1"]')).toHaveLength(1);
      expect(wrapper.find('#message1 [role="status"]').text()).toBe(
        outcome === 'accepted'
          ? 'Accepted by WhatsApp; awaiting delivery'
          : 'Delivery unknown'
      );
      expect(wrapper.find('button[aria-label="Retry delivery"]').exists()).toBe(
        false
      );
    }
  );

  it('retains normal same-minute grouping for messages without owned delivery state', async () => {
    const wrapper = await mountMessages([reply(1), reply(2)]);
    expect(wrapper.find('#message1').findComponent(MessageMeta).exists()).toBe(
      false
    );
    expect(wrapper.find('#message2').findComponent(MessageMeta).exists()).toBe(
      true
    );
  });
});
