FROM --platform=linux/amd64 jrottenberg/ffmpeg:6.1-ubuntu AS base

RUN apt-get update && apt-get install -y \
    curl \
    python3 \
    python3-pip \
    libfreetype6 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && pip3 install yt-dlp --break-system-packages \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY src/ ./src/

ENTRYPOINT ["node", "src/index.js"]
