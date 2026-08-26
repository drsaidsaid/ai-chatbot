/* global axios */

import ApiClient from './ApiClient';

class OperationalDashboardAPI extends ApiClient {
  constructor() {
    super('operational_dashboard', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new OperationalDashboardAPI();
