# 7-Zip CPU Benchmark Container
FROM alpine:latest

# Install 7-Zip
RUN apk add --no-cache p7zip

# Create benchmark script
COPY benchmark.sh /benchmark.sh
RUN chmod +x /benchmark.sh

# Set entrypoint
ENTRYPOINT ["/benchmark.sh"]
