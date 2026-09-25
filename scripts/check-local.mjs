#!/usr/bin/env node
/**
 * One line when the local checkouts named in project.local.sh no longer match
 * what the project uses. Read-only, and fast enough for every build. See
 * local.mjs and sync-local.mjs.
 */

import { staleness } from './local.mjs';

const stale = staleness(process.cwd());
if (stale.length > 0) {
    console.log(`  local checkouts changed (${stale.join('; ')}): run npm run sync-local`);
}
