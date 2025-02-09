# --- Base Image ---
FROM node:18-bullseye-slim AS base
ARG NX_CLOUD_ACCESS_TOKEN

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV NODE_VERSION=18

# Installer pnpm directement
RUN corepack disable
RUN npm install -g pnpm@latest

WORKDIR /app

# --- Build Image ---
FROM base AS build
ARG NX_CLOUD_ACCESS_TOKEN

# Supprimer le cache pour éviter les conflits de dépendances
RUN pnpm store prune && rm -rf node_modules .pnpm-store

COPY .npmrc package.json pnpm-lock.yaml ./
COPY ./tools/prisma /app/tools/prisma

# Installation forcée des dépendances avec la bonne option
RUN pnpm install --frozen-lockfile --no-optional --config.strict-peer-dependencies=false

COPY . .

ENV NX_CLOUD_ACCESS_TOKEN=$NX_CLOUD_ACCESS_TOKEN

# Reconstruire les dépendances natives
RUN pnpm rebuild @swc/core

# Exécuter la build
RUN pnpm run build

# --- Release Image ---
FROM base AS release
ARG NX_CLOUD_ACCESS_TOKEN

RUN apt update && apt install -y dumb-init --no-install-recommends && rm -rf /var/lib/apt/lists/*

COPY --chown=node:node --from=build /app/.npmrc /app/package.json /app/pnpm-lock.yaml ./

# Installation en mode production
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
