# -------- build stage --------
FROM node:20-bookworm-slim AS builder
WORKDIR /app

# 让 corepack 管 pnpm（按 packageManager 字段 / 默认版本）
RUN corepack enable

# 先拷贝依赖相关文件，最大化缓存
COPY package.json pnpm-lock.yaml .npmrc* ./

# CI 下 pnpm 默认可能 frozen lockfile，容易报错；先用 --no-frozen-lockfile 走通
RUN pnpm install --no-frozen-lockfile

# 再拷贝全部源码并构建
COPY . .
RUN pnpm run build

# -------- runtime stage --------
FROM nginx:1.27-alpine
COPY --from=builder /app/dist/browser /usr/share/nginx/html

# SPA 回落（/system 这种前端路由必须回到 index.html）
RUN printf '%s\n' \
'server {' \
'  listen 80;' \
'  server_name _;' \
'  root /usr/share/nginx/html;' \
'  index index.html;' \
'  location / {' \
'    try_files $uri $uri/ /index.html;' \
'  }' \
'}' > /etc/nginx/conf.d/default.conf
