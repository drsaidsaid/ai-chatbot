/* global axios */

import ApiClient from './ApiClient';

class AiSubscriptionAPI extends ApiClient {
  constructor() {
    super('ai_subscription', { accountScoped: true });
  }

  createRequest(data) {
    return axios.post(`${this.url}/requests`, data);
  }

  previewPurchase(data) {
    return axios.post(`${this.url}/preview`, data);
  }
}

export default new AiSubscriptionAPI();
