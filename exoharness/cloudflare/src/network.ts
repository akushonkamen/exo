import { WorkerEntrypoint } from "cloudflare:workers";
import type { Env, SandboxIdentity } from "./env";

export interface ProxyHeaders {
  headers: [string, string][];
  credentials: [string, string][];
  refreshed: boolean;
}

export type ProxyReply = ProxyHeaders | { status: number; error: string };

export async function proxyEgress(
  identity: SandboxIdentity,
  request: Request,
  provider:
    | Pick<import("./provider").ExoProvider, "proxyHeaders">
    | Pick<DurableObjectStub<import("./provider").ExoProvider>, "proxyHeaders">,
): Promise<Response> {
  let policy: ProxyReply;
  try {
    policy = (await provider.proxyHeaders(identity, request)) as ProxyReply;
  } catch (error) {
    console.error("Exo egress policy lookup failed", String(error));
    return new Response("Exo egress policy lookup failed", { status: 502 });
  }
  if ("error" in policy) {
    console.warn("Exo egress policy rejected request", policy.error);
    return new Response("Exo egress policy rejected request", {
      status: policy.status,
    });
  }
  const replay = policy.credentials.length > 0 ? request.clone() : null;
  const send = (source: Request, headers: [string, string][]) =>
    fetch(new Request(source, { headers, redirect: "manual" }));
  try {
    let response = await send(request, policy.headers);
    if (response.status === 401 && replay) {
      const fresh = (await provider.proxyHeaders(
        identity,
        replay,
        policy.credentials,
      )) as ProxyReply;
      if ("error" in fresh) {
        await response.body?.cancel();
        console.error("Exo egress credential retry failed", fresh.error);
        return new Response("Exo egress credential retry failed", {
          status: fresh.status,
        });
      }
      if (fresh.refreshed) {
        await response.body?.cancel();
        response = await send(replay, fresh.headers);
      }
    }
    return response;
  } catch (error) {
    console.error("Exo egress request failed", String(error));
    return new Response("Exo egress request failed", { status: 502 });
  } finally {
    if (replay?.body && !replay.bodyUsed)
      replay.body
        .cancel()
        .catch((error) =>
          console.error("Exo egress replay cleanup failed", String(error)),
        );
  }
}

// Native interception supplies trusted identity props, independent of sandbox headers.
export class ExoEgress extends WorkerEntrypoint<Env, SandboxIdentity> {
  fetch(request: Request): Promise<Response> {
    return proxyEgress(
      this.ctx.props,
      request,
      this.env.PROVIDERS.getByName(this.env.ACCOUNT_ID),
    );
  }
}
