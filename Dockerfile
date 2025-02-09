# --- Base Image ---
FROM node:lts-bullseye-slim AS base
ARG NX_CLOUD_ACCESS_TOKEN

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Désactiver Corepack pour éviter les erreurs de signature
RUN corepack disable

WORKDIR /app

# --- Build Image ---
FROM base AS build
ARG NX_CLOUD_ACCESS_TOKEN

# Désactiver la vérification d'intégrité de pnpm
RUN pnpm config set verify-store-integrity false

COPY .npmrc package.json pnpm-lock.yaml ./
COPY ./tools/prisma /app/tools/prisma

# Correction de l'erreur d'installation de pnpm
RUN pnpm install --frozen-lockfile --no-optional

COPY . .

ENV NX_CLOUD_ACCESS_TOKEN=$NX_CLOUD_ACCESS_TOKEN

RUN pnpm run build

# --- Release Image ---
FROM base AS release
ARG NX_CLOUD_ACCESS_TOKEN

RUN apt update && apt install -y dumb-init --no-install-recommends && rm -rf /var/lib/apt/lists/*

COPY --chown=node:node --from=build /app/.npmrc /app/package.json /app/pnpm-lock.yaml ./

# Installation en mode production uniquement
RUN pnpm install --prod --frozen-lockfile --no-optional

COPY --chown=node:node --from=build /app/dist ./dist
COPY --chown=node:node --from=build /app/tools/prisma ./tools/prisma

# Génération du client Prisma
RUN pnpm run prisma:generate

# Variables d'environnement
ENV TZ=UTC
ENV PORT=3000
ENV NODE_ENV=production

EXPOSE 3000

CMD [ "dumb-init", "pnpm", "run", "start" ]
