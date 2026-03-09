FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npx tsc

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist
COPY drizzle.config.ts ./
COPY src/db ./src/db

EXPOSE 3000

CMD ["sh", "-c", "npx drizzle-kit push && (npx tsx src/db/seed.ts || echo 'Seed skipped') && node dist/index.js"]
