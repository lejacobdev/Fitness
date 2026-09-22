import { createApp } from './app.js';
import { disconnectPrisma, prisma } from './lib/prisma.js';

const port = Number(process.env.PORT ?? 8080);
const app = createApp({ prisma });

const server = app.listen(port, () => {
  console.log(`[boot] listening on ${port}`);
});

async function shutdown(signal) {
  console.log(`[shutdown] ${signal}`);
  server.close(async () => {
    await disconnectPrisma();
    process.exit(0);
  });
  // A connection that will not drain must not hold the deploy open forever.
  setTimeout(() => process.exit(1), 10_000).unref();
}

for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => shutdown(signal));
}
