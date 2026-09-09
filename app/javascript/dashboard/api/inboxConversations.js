/* global axios */

import ApiClient from './ApiClient';

class InboxConversationsAPI extends ApiClient {
  constructor() {
    super('inbox_conversations', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new InboxConversationsAPI();
