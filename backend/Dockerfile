# Node 20 per §3 — the stack shape that is already proven end to end.
#
# Build context is the REPO ROOT (see docker-compose.yml), not backend/,
# specifically so this stage can reach the sibling content/ directory to
# build the packs it serves — §3's "content packs" responsibility needs the
# actual pack files, not just the route that serves them.
FROM node:20-bookworm-slim AS content-packs

WORKDIR /content
COPY content/package.json content/package-lock.json ./
RUN npm ci
COPY content/ ./
RUN npm run build


FROM node:20-bookworm-slim AS deps

WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev

COPY backend/prisma ./prisma
RUN npx prisma generate


FROM node:20-bookworm-slim AS runtime

WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
ENV PACKS_DIR=/app/packs

COPY --from=deps /app/node_modules ./node_modules
COPY backend/package.json backend/package-lock.json ./
COPY backend/prisma ./prisma
COPY backend/src ./src
COPY --from=content-packs /content/dist ./packs

USER node
EXPOSE 8080

# §19: `prisma migrate deploy` runs in the CMD, not in a separate deploy step, so
# a redeploy can never come up against a stale schema. If the migration fails the
# container does not start, which is the intended outcome.
CMD ["sh", "-c", "npx prisma migrate deploy && node src/server.js"]
