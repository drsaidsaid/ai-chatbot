/* global axios */

import ApiClient from './ApiClient';

class AlertConfigurationAPI extends ApiClient {
  constructor() {
    super('alert_configuration', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  update(data) {
    return axios.patch(this.url, data);
  }
}

export default new AlertConfigurationAPI();
