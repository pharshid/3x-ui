# ========================================================
# Stage: Builder
# ========================================================
FROM golang:1.24 AS builder
WORKDIR /app
ARG TARGETARCH

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY . .

# Set environment variables
ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"

# Build the application
RUN go build -ldflags "-w -s" -o build/x-ui main.go
RUN ./DockerInit.sh "$TARGETARCH"

# ========================================================
# Stage: Final Image of 3x-ui
# ========================================================
FROM debian:bullseye-slim
ENV TZ=Asia/Tehran
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    fail2ban \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Copy files from builder
COPY --from=builder /app/build/ /app/
COPY --from=builder /app/DockerEntrypoint.sh /app/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui

# Configure fail2ban
RUN cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
  && sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf

# Set permissions
RUN chmod +x \
  /app/DockerEntrypoint.sh \
  /app/x-ui \
  /usr/bin/x-ui

# Set environment variable
ENV XUI_ENABLE_FAIL2BAN="true"

# Volume for configuration
VOLUME [ "/etc/x-ui" ]

# Default command
CMD [ "./x-ui" ]

# Entrypoint
ENTRYPOINT [ "/app/DockerEntrypoint.sh" ]
