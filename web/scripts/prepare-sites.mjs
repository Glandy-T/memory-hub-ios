import { mkdir, readdir, rm, writeFile } from "node:fs/promises";

const distDirectory = new URL("../dist/", import.meta.url);

for (const entry of await readdir(distDirectory)) {
  if (entry !== "client") {
    await rm(new URL(entry, distDirectory), { recursive: true, force: true });
  }
}

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

await mkdir(new URL("server/", distDirectory), { recursive: true });
await writeFile(new URL("server/index.js", distDirectory), worker, "utf8");
