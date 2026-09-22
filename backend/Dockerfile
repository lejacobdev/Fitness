# Node 20 per §3 — the stack shape that is already proven end to end.
FROM node:20-bookworm-slim AS deps

WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY prisma ./prisma
RUN npx prisma generate


FROM node:20-bookworm-slim AS runtime

WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json ./
COPY prisma ./prisma
COPY src ./src

USER node
EXPOSE 8080

# §19: `prisma migrate deploy` runs in the CMD, not in a separate deploy step, so
# a redeploy can never come up against a stale schema. If the migration fails the
# container does not start, which is the intended outcome.
CMD ["sh", "-c", "npx prisma migrate deploy && node src/server.js"]
