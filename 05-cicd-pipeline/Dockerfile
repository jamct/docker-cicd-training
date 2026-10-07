# syntax=docker/dockerfile:1
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY app/package*.json ./
RUN npm install --omit=dev
COPY --chown=node:node app/ .

# Wird von der Pipeline gesetzt (Git-Commit), landet in der Antwort der App
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "server.js"]
