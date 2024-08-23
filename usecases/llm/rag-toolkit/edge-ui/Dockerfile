FROM node:22 AS base
FROM base AS deps

WORKDIR /app
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

FROM base AS development

ENV NODE_ENV development
ENV NEXT_TELEMETRY_DISABLED 1
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

RUN useradd -m intel
WORKDIR /app
COPY package*.json ./
RUN npm install
USER intel

FROM base AS builder

ARG REACT_APP_API_URL=localhost
ENV REACT_APP_API_URL=$REACT_APP_API_URL
WORKDIR /app
COPY package*.json ./
COPY --from=deps /app/node_modules ./node_modules
RUN npm install
COPY . .
RUN npm run build

FROM base AS runner

WORKDIR /app
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN useradd -m intel

COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./
RUN npm install --production
COPY --from=builder /app/.next ./.next
RUN chown -R intel:intel /app
RUN chmod 755 /app

USER intel
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["npm", "start"]