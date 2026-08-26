/* global axios */

import ApiClient from './ApiClient';

class BookingConfigurationAPI extends ApiClient {
  constructor() {
    super('booking_configuration', { accountScoped: true });
  }

  update(data) {
    return axios.patch(this.url, data);
  }
}

export default new BookingConfigurationAPI();
