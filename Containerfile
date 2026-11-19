FROM ubuntu:rolling

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git gh curl ca-certificates build-essential sudo nodejs npm \
 && rm -rf /var/lib/apt/lists/*

# Non-root user with passwordless sudo: Claude may install toolchains per project.
RUN useradd -m -s /bin/bash claude \
 && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude

# Git over https authenticates with GH_TOKEN (or GITHUB_TOKEN) injected at exec time.
# The VM has no ssh keys, so ssh GitHub URLs are rewritten to https.
RUN git config --system credential.https://github.com.helper \
      '!f() { echo username=x-access-token; echo "password=${GH_TOKEN:-$GITHUB_TOKEN}"; }; f' \
 && git config --system --add url.https://github.com/.insteadOf git@github.com: \
 && git config --system --add url.https://github.com/.insteadOf ssh://git@github.com/

USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/claude/.local/bin:$PATH
COPY --chown=claude:claude claude-home/ /home/claude/.claude/
WORKDIR /work
