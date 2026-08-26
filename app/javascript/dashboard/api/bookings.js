/* global axios */

import ApiClient from './ApiClient';

class BookingsAPI extends ApiClient {
  constructor() {
    super('bookings', { accountScoped: true });
  }

  availableSlots(params = {}) {
    return axios.get(`${this.url}/available_slots`, { params });
  }
}

export default new BookingsAPI();
