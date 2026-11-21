// Läser de gyllene spåren som Swift-modellen skrev (se test/spar/SparTests.swift).
import { readFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";

export const facit = JSON.parse(gunzipSync(readFileSync(new URL("./spar/spar.json.gz", import.meta.url))).toString("utf8"));
