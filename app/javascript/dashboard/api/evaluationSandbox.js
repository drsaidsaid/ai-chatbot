/* global axios */

import ApiClient from './ApiClient';

class EvaluationSandboxAPI extends ApiClient {
  constructor() {
    super('evaluation_sandbox', { accountScoped: true });
  }

  scenarios() {
    return axios.get(`${this.url}/scenarios`);
  }

  runs() {
    return axios.get(`${this.url}/runs`);
  }

  createRun(data) {
    return axios.post(`${this.url}/runs`, data);
  }

  gradeRun(runId, data) {
    return axios.post(`${this.url}/runs/${runId}/grade`, data);
  }

  launchGate() {
    return axios.get(`${this.url}/launch_gate`);
  }

  updateLaunchGate(data) {
    return axios.patch(`${this.url}/launch_gate`, data);
  }

  approveLaunch(data) {
    return axios.post(`${this.url}/approve_launch`, data);
  }
}

export default new EvaluationSandboxAPI();
