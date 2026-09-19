/* global axios */

import ApiClient from './ApiClient';

class BookingConfigurationAPI extends ApiClient {
  constructor() {
    super('booking_configuration', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  update(data) {
    return axios.patch(this.url, data);
  }

  connectGoogle() {
    return axios.post(
      `${this.url.replace('booking_configuration', 'google_calendar_connection')}`
    );
  }

  disconnectGoogle() {
    return axios.delete(
      `${this.url.replace('booking_configuration', 'google_calendar_connection')}`
    );
  }
}

export default new BookingConfigurationAPI();
