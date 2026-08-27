/* global axios */

import ApiClient from './ApiClient';

class EvaluationSandboxAPI extends ApiClient {
  constructor() {
    super('evaluation_sandbox', { accountScoped: true });
  }

  scenarios() {
    return axios.get(`${this.url}/scenarios`);
  }

  runs(params = {}) {
    return axios.get(`${this.url}/runs`, { params });
  }

  runScenario(scenarioKey) {
    return axios.post(`${this.url}/runs`, { scenario_key: scenarioKey });
  }

  gradeRun(runId, data) {
    return axios.patch(`${this.url}/runs/${runId}/grade`, { grades: data });
  }

  proposeKnowledge(runId, correction) {
    return axios.post(`${this.url}/runs/${runId}/propose_knowledge`, {
      correction,
    });
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
