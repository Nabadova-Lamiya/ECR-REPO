# ---- builder ----
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src

# ---- runtime ----
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY package*.json ./
USER node
EXPOSE 3000
CMD ["node", "src/index.js"]
