/* global axios */

import ApiClient from './ApiClient';

class QualificationConfigurationAPI extends ApiClient {
  constructor() {
    super('qualification_configuration', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  update(data) {
    return axios.patch(this.url, data);
  }
}

export default new QualificationConfigurationAPI();
