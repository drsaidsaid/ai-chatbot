/* global axios */

import ApiClient from './ApiClient';

class LeadQualificationsAPI extends ApiClient {
  constructor() {
    super('lead_qualifications', { accountScoped: true });
  }

  evidence(contactId, payload) {
    return axios.post(`${this.url}/${contactId}/evidence`, payload);
  }

  forOffer(contactId, offerId) {
    return axios.get(`${this.url}/${contactId}`, {
      params: { offer_id: offerId || undefined },
    });
  }
}

export default new LeadQualificationsAPI();
