/* global axios */

import ApiClient from './ApiClient';

class WhatsappTemplatesAPI extends ApiClient {
  constructor() {
    super('whatsapp_templates', { accountScoped: true });
  }

  submit(id) {
    return axios.post(`${this.url}/${id}/submit`);
  }

  reconcile(id) {
    return axios.post(`${this.url}/${id}/reconcile`);
  }
}

export default new WhatsappTemplatesAPI();
