FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src

FROM node:20-alpine

WORKDIR /app
COPY --from=builder /app .

EXPOSE 3001
CMD ["node", "src/index.js"]
