import { copyFile, mkdir, readdir, rm } from "node:fs/promises";

const distDirectory = new URL("../dist/", import.meta.url);

for (const entry of await readdir(distDirectory)) {
  if (entry !== "client") {
    await rm(new URL(entry, distDirectory), { recursive: true, force: true });
  }
}

await mkdir(new URL("server/", distDirectory), { recursive: true });
await copyFile(
  new URL("../worker/index.js", import.meta.url),
  new URL("server/index.js", distDirectory)
);
