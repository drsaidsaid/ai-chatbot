import { ChatwootApi } from "./chatwoot.js";
import { ConversationService } from "./conversation-service.js";
import { InMemoryLeadRepository } from "./in-memory-repository.js";

function createRuntime() {
  const repository = new InMemoryLeadRepository();
  const chatwootApi = new ChatwootApi({
    baseUrl: process.env.CHATWOOT_BASE_URL,
    accountId: process.env.CHATWOOT_ACCOUNT_ID,
    apiToken: process.env.CHATWOOT_API_TOKEN,
  });

  return {
    repository,
    service: new ConversationService({
      repository,
      chatwootApi,
      businessAccountId: process.env.BUSINESS_ACCOUNT_ID ?? "local-business-account",
    }),
  };
}

export function getRuntime() {
  if (!globalThis.__aiLeadEmployeeRuntime) {
    globalThis.__aiLeadEmployeeRuntime = createRuntime();
  }
  return globalThis.__aiLeadEmployeeRuntime;
}
