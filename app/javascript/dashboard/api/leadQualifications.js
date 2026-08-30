/* global axios */

import ApiClient from './ApiClient';

class LeadQualificationsAPI extends ApiClient {
  constructor() {
    super('lead_qualifications', { accountScoped: true });
  }

  evidence(contactId, payload) {
    return axios.post(`${this.url}/${contactId}/evidence`, payload);
  }
}

export default new LeadQualificationsAPI();
