import { mkdir, writeFile } from "node:fs/promises";

const worker = `export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const assetRequest = url.pathname === "/"
      ? new Request(new URL("/index.html", url), request)
      : request;
    const response = await env.ASSETS.fetch(assetRequest);

    if (response.status !== 404 || request.method !== "GET") {
      return response;
    }

    return env.ASSETS.fetch(new Request(new URL("/index.html", url), request));
  }
};
`;

await mkdir(new URL("../dist/server/", import.meta.url), { recursive: true });
await writeFile(new URL("../dist/server/index.js", import.meta.url), worker, "utf8");
