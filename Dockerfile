# ---- Stage 1: build frontend ----
# 国内网络构建时加: --build-arg NPM_REGISTRY=https://registry.npmmirror.com
ARG NPM_REGISTRY=https://registry.npmjs.org
FROM node:22-alpine AS frontend

ARG NPM_REGISTRY=https://registry.npmjs.org
WORKDIR /build/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --registry=${NPM_REGISTRY}

COPY frontend/ ./
# vite outDir = ../src/qoder2api/static -> /build/src/qoder2api/static
RUN npm run build

# ---- Stage 2: python runtime ----
# 国内网络构建时加: --build-arg PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ARG PIP_INDEX_URL=https://pypi.org/simple
FROM python:3.12-slim AS runtime

ARG PIP_INDEX_URL=https://pypi.org/simple
ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_LINK_MODE=copy \
    UV_INDEX_URL=${PIP_INDEX_URL}

RUN pip install --no-cache-dir -i ${PIP_INDEX_URL} uv

WORKDIR /app

# 先复制依赖清单以利用构建缓存
COPY pyproject.toml uv.lock ./

# pypiwin32 是 Windows 专用依赖（仅批量注册功能用到，函数内懒加载），容器内移除
RUN sed -i '/"pypiwin32>=223",/d' pyproject.toml && uv sync --no-dev

COPY src/ ./src/
COPY --from=frontend /build/src/qoder2api/static ./src/qoder2api/static

RUN useradd -m -u 10001 appuser \
    && mkdir -p /home/appuser/.qoder \
    && chown -R appuser:appuser /app /home/appuser/.qoder
USER appuser
ENV HOME=/home/appuser

EXPOSE 5050

CMD ["uv", "run", "--no-sync", "qoder2api", "--host", "0.0.0.0", "--port", "5050"]
