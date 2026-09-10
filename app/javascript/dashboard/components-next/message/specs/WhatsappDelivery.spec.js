import { computed, defineComponent, ref, toRef } from 'vue';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import MessageMeta from '../MessageMeta.vue';
import MessageError from '../MessageError.vue';
import MessageStatus from '../MessageStatus.vue';
import { provideMessageContext } from '../provider';
import chatlist from 'dashboard/i18n/locale/en/chatlist.json';

const wrappers = [];
const mountDelivery = (state, status = 'sent', sourceId = null) => {
  const TestHost = defineComponent({
    components: { MessageMeta, MessageError },
    props: {
      status: { type: String, required: true },
      contentAttributes: { type: Object, required: true },
    },
    setup(props) {
      provideMessageContext({
        status: toRef(props, 'status'),
        isPrivate: ref(false),
        createdAt: ref(Math.floor(Date.now() / 1000)),
        sourceId: ref(sourceId),
        messageType: ref(1),
        contentAttributes: toRef(props, 'contentAttributes'),
        orientation: ref('right'),
        content: ref('A persisted reply'),
        attachments: ref([]),
      });
      return { failed: computed(() => props.status === 'failed') };
    },
    template:
      '<div><MessageMeta /><MessageError v-if="failed" error="Check the connection." /></div>',
  });
  const store = createStore({
    getters: {
      getSelectedChat: () => ({ inbox_id: 1 }),
      'inboxes/getInboxById': () => () => ({
        id: 1,
        channel_type: 'Channel::Whatsapp',
      }),
      getSelectedChatAttachments: () => [],
    },
  });
  const wrapper = mount(TestHost, {
    props: { status, contentAttributes: { whatsappDelivery: { state } } },
    global: {
      plugins: [
        store,
        createI18n({ legacy: false, locale: 'en', messages: { en: chatlist } }),
      ],
      directives: { tooltip: () => {} },
    },
  });
  wrappers.push(wrapper);
  return wrapper;
};

afterEach(() => wrappers.splice(0).forEach(wrapper => wrapper.unmount()));

describe('WhatsApp delivery outcomes in the Inbox', () => {
  it.each([
    ['pending', 'Pending'],
    ['canceled', 'Canceled'],
    ['unknown', 'Delivery unknown'],
  ])('shows an honest %s outcome', (state, text) => {
    expect(mountDelivery(state).text()).toContain(text);
  });

  it('does not offer a retry for uncertain acceptance or a provider-accepted message', () => {
    expect(mountDelivery('unknown', 'failed').find('button').exists()).toBe(
      false
    );
    expect(
      mountDelivery('accepted', 'failed', 'wamid.ACCEPTED')
        .find('button')
        .exists()
    ).toBe(false);
  });

  it('offers a retry for a definite failure before provider acceptance', async () => {
    const wrapper = mountDelivery('failed', 'failed');
    await wrapper.get('button').trigger('click');
    expect(wrapper.getComponent(MessageError).emitted('retry')).toHaveLength(1);
  });

  it.each(['sent', 'delivered', 'read'])(
    'waits for provider evidence before advancing to %s',
    async providerStatus => {
      const wrapper = mountDelivery('accepted', 'sent', 'wamid.ACCEPTED');
      expect(wrapper.text()).toContain(
        'Accepted by WhatsApp; awaiting delivery'
      );
      expect(wrapper.findComponent(MessageStatus).exists()).toBe(false);

      await wrapper.setProps({
        status: providerStatus,
        contentAttributes: {
          whatsappDelivery: { state: 'accepted' },
          whatsappProviderStatus: providerStatus,
        },
      });
      expect(wrapper.text()).not.toContain('awaiting delivery');
      expect(wrapper.getComponent(MessageStatus).props('status')).toBe(
        providerStatus
      );
      await wrapper.setProps({ status: 'failed' });
      expect(wrapper.findComponent(MessageStatus).exists()).toBe(false);
      expect(wrapper.text()).toContain('Delivery failed');
      expect(wrapper.find('button').exists()).toBe(false);
    }
  );
});
