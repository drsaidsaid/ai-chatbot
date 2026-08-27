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

  reschedule(id, data) {
    return axios.patch(`${this.url}/${id}/reschedule`, data);
  }

  cancel(id, data) {
    return axios.post(`${this.url}/${id}/cancel`, data);
  }
}

export default new BookingsAPI();
