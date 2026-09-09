/* global axios */
import ApiClient from './ApiClient';

class WhatsappConnectionAPI extends ApiClient {
  constructor() {
    super('whatsapp_connection', { accountScoped: true });
  }

  save(data) {
    return axios.patch(this.url, data);
  }

  check() {
    return axios.post(`${this.url}/health_check`);
  }

  retryReceiving() {
    return axios.post(`${this.url}/retry_receiving`);
  }
}

export default new WhatsappConnectionAPI();
