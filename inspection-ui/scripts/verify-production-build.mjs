import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const assets = join(process.cwd(), "dist", "assets");
const javascript = readdirSync(assets)
  .filter((name) => name.endsWith(".js"))
  .map((name) => readFileSync(join(assets, name), "utf8"))
  .join("\n");

for (const marker of ["fixture-07-b", "east_field"]) {
  if (javascript.includes(marker)) {
    throw new Error(`Production inspection build contains fixture marker: ${marker}`);
  }
}

for (const message of ["inspection:", "inspection:close"]) {
  if (!javascript.includes(message)) {
    throw new Error(`Production inspection build is missing runtime message: ${message}`);
  }
}

console.log("production contract passed: runtime messages present, fixtures absent");
