/* global axios */

import ApiClient from './ApiClient';

class BookingsAPI extends ApiClient {
  constructor() {
    super('bookings', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  availableSlots(params = {}) {
    return axios.get(`${this.url}/available_slots`, { params });
  }

  create(data) {
    return axios.post(this.url, data);
  }

  propose(data) {
    return axios.post(`${this.url}/propose`, data);
  }

  reschedule(id, data) {
    return axios.patch(`${this.url}/${id}/reschedule`, data);
  }

  cancel(id, data) {
    return axios.post(`${this.url}/${id}/cancel`, data);
  }

  reconcile(id) {
    return axios.post(`${this.url}/${id}/reconcile`);
  }
}

export default new BookingsAPI();
