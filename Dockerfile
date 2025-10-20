# Railway-compatible Dockerfile (without --mount syntax)
# deps stage - pull dependencies image
FROM infiniflow/ragflow_deps:latest AS deps

# base stage
FROM ubuntu:22.04 AS base
USER root
SHELL ["/bin/bash", "-c"]

ARG NEED_MIRROR=0
ARG LIGHTEN=0
ENV LIGHTEN=${LIGHTEN}

WORKDIR /ragflow

# Copy models from deps image
RUN mkdir -p /ragflow/rag/res/deepdoc /root/.ragflow

COPY --from=deps /huggingface.co/InfiniFlow/huqie/huqie.txt.trie /ragflow/rag/res/
COPY --from=deps /huggingface.co/InfiniFlow/text_concat_xgb_v1.0 /tmp/text_concat_xgb_v1.0
COPY --from=deps /huggingface.co/InfiniFlow/deepdoc /tmp/deepdoc

RUN mv /tmp/text_concat_xgb_v1.0 /ragflow/rag/res/deepdoc/ && \
    mv /tmp/deepdoc /ragflow/rag/res/deepdoc/

# Copy embeddings if not LIGHTEN mode
COPY --from=deps /huggingface.co/BAAI/bge-large-zh-v1.5 /tmp/bge-large-zh-v1.5
COPY --from=deps /huggingface.co/maidalun1020/bce-embedding-base_v1 /tmp/bce-embedding-base_v1

RUN if [ "$LIGHTEN" != "1" ]; then \
        mv /tmp/bge-large-zh-v1.5 /root/.ragflow/ && \
        mv /tmp/bce-embedding-base_v1 /root/.ragflow/; \
    else \
        rm -rf /tmp/bge-large-zh-v1.5 /tmp/bce-embedding-base_v1; \
    fi

# Copy other dependencies from deps image
COPY --from=deps /nltk_data /root/nltk_data
COPY --from=deps /tika-server-standard-3.0.0.jar /ragflow/
COPY --from=deps /tika-server-standard-3.0.0.jar.md5 /ragflow/
COPY --from=deps /cl100k_base.tiktoken /ragflow/9b5ad71b2ce5302211f9c61530b329a4922fc6a4

ENV TIKA_SERVER_JAR="file:///ragflow/tika-server-standard-3.0.0.jar"
ENV DEBIAN_FRONTEND=noninteractive

# Setup apt
# Python package and implicit dependencies:
# opencv-python: libglib2.0-0 libglx-mesa0 libgl1
# aspose-slides: pkg-config libicu-dev libgdiplus         libssl1.1_1.1.1f-1ubuntu2_amd64.deb
# python-pptx:   default-jdk                              tika-server-standard-3.0.0.jar
# selenium:      libatk-bridge2.0-0                       chrome-linux64-121-0-6167-85
# Building C extensions: libpython3-dev libgtk-4-1 libnss3 xdg-utils libgbm-dev
RUN if [ "$NEED_MIRROR" == "1" ]; then \
        sed -i 's|http://ports.ubuntu.com|http://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list; \
        sed -i 's|http://archive.ubuntu.com|http://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list; \
    fi; \
    apt update && \
    apt --no-install-recommends install -y ca-certificates && \
    apt update && \
    apt install -y libglib2.0-0 libglx-mesa0 libgl1 && \
    apt install -y pkg-config libicu-dev libgdiplus && \
    apt install -y default-jdk && \
    apt install -y libatk-bridge2.0-0 && \
    apt install -y libpython3-dev libgtk-4-1 libnss3 xdg-utils libgbm-dev && \
    apt install -y libjemalloc-dev && \
    apt install -y python3-pip pipx nginx unzip curl wget git vim less && \
    apt install -y ghostscript && \
    apt clean && rm -rf /var/lib/apt/lists/*

RUN if [ "$NEED_MIRROR" == "1" ]; then \
        pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple && \
        pip3 config set global.trusted-host mirrors.aliyun.com; \
        mkdir -p /etc/uv && \
        echo "[[index]]" > /etc/uv/uv.toml && \
        echo 'url = "https://mirrors.aliyun.com/pypi/simple"' >> /etc/uv/uv.toml && \
        echo "default = true" >> /etc/uv/uv.toml; \
    fi; \
    pipx install uv

ENV PYTHONDONTWRITEBYTECODE=1 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV PATH=/root/.local/bin:$PATH

# nodejs 12.22 on Ubuntu 22.04 is too old
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt purge -y nodejs npm cargo && \
    apt autoremove -y && \
    apt update && \
    apt install -y nodejs && \
    apt clean && rm -rf /var/lib/apt/lists/*

# A modern version of cargo is needed for the latest version of the Rust compiler.
RUN apt update && apt install -y curl build-essential \
    && if [ "$NEED_MIRROR" == "1" ]; then \
         # Use TUNA mirrors for rustup/rust dist files
         export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"; \
         export RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"; \
         echo "Using TUNA mirrors for Rustup."; \
       fi; \
    # Force curl to use HTTP/1.1
    curl --proto '=https' --tlsv1.2 --http1.1 -sSf https://sh.rustup.rs | bash -s -- -y --profile minimal \
    && echo 'export PATH="/root/.cargo/bin:${PATH}"' >> /root/.bashrc

ENV PATH="/root/.cargo/bin:${PATH}"

RUN cargo --version && rustc --version

# Add msssql ODBC driver
# macOS ARM64 environment, install msodbcsql18.
# general x86_64 environment, install msodbcsql17.
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt update && \
    arch="$(uname -m)"; \
    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then \
        # ARM64 (macOS/Apple Silicon or Linux aarch64)
        ACCEPT_EULA=Y apt install -y unixodbc-dev msodbcsql18; \
    else \
        # x86_64 or others
        ACCEPT_EULA=Y apt install -y unixodbc-dev msodbcsql17; \
    fi && \
    apt clean && rm -rf /var/lib/apt/lists/* || \
    { echo "Failed to install ODBC driver"; exit 1; }



# Add dependencies of selenium
COPY --from=deps /chrome-linux64-121-0-6167-85 /tmp/chrome-linux64.zip
RUN unzip /tmp/chrome-linux64.zip && \
    mv chrome-linux64 /opt/chrome && \
    ln -s /opt/chrome/chrome /usr/local/bin/ && \
    rm /tmp/chrome-linux64.zip

COPY --from=deps /chromedriver-linux64-121-0-6167-85 /tmp/chromedriver-linux64.zip
RUN unzip -j /tmp/chromedriver-linux64.zip chromedriver-linux64/chromedriver && \
    mv chromedriver /usr/local/bin/ && \
    rm -f /usr/bin/google-chrome /tmp/chromedriver-linux64.zip

# https://forum.aspose.com/t/aspose-slides-for-net-no-usable-version-of-libssl-found-with-linux-server/271344/13
# aspose-slides on linux/arm64 is unavailable
COPY --from=deps /libssl1.1_1.1.1f-1ubuntu2_amd64.deb /tmp/
COPY --from=deps /libssl1.1_1.1.1f-1ubuntu2_arm64.deb /tmp/

RUN if [ "$(uname -m)" = "x86_64" ]; then \
        dpkg -i /tmp/libssl1.1_1.1.1f-1ubuntu2_amd64.deb; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
        dpkg -i /tmp/libssl1.1_1.1.1f-1ubuntu2_arm64.deb; \
    fi && \
    rm -f /tmp/libssl*.deb


# builder stage
FROM base AS builder
USER root

WORKDIR /ragflow

# install dependencies from uv.lock file
COPY pyproject.toml uv.lock ./

# https://github.com/astral-sh/uv/issues/10462
# uv records index url into uv.lock but doesn't failover among multiple indexes
RUN if [ "$NEED_MIRROR" == "1" ]; then \
        sed -i 's|pypi.org|mirrors.aliyun.com/pypi|g' uv.lock; \
    else \
        sed -i 's|mirrors.aliyun.com/pypi|pypi.org|g' uv.lock; \
    fi; \
    if [ "$LIGHTEN" == "1" ]; then \
        uv sync --python 3.10 --frozen; \
    else \
        uv sync --python 3.10 --frozen --all-extras; \
    fi

COPY web web
COPY docs docs
RUN cd web && npm install && npm run build

# Generate version info without .git dependency (Railway compatible)
RUN version_info="v2.0-railway-$(date +%Y%m%d-%H%M%S)"; \
    if [ "$LIGHTEN" == "1" ]; then \
        version_info="$version_info slim"; \
    else \
        version_info="$version_info full"; \
    fi; \
    echo "RAGFlow version: $version_info"; \
    echo $version_info > /ragflow/VERSION

# production stage
FROM base AS production
USER root

WORKDIR /ragflow

# Copy Python environment and packages
ENV VIRTUAL_ENV=/ragflow/.venv
COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

ENV PYTHONPATH=/ragflow/

COPY web web
COPY admin admin
COPY api api
COPY conf conf
COPY deepdoc deepdoc
COPY rag rag
COPY agent agent
COPY graphrag graphrag
COPY agentic_reasoning agentic_reasoning
COPY pyproject.toml uv.lock ./
COPY mcp mcp
COPY plugin plugin

COPY docker/service_conf.yaml.template ./conf/service_conf.yaml.template
COPY docker/entrypoint.sh ./
RUN chmod +x ./entrypoint*.sh

# Copy compiled web pages
COPY --from=builder /ragflow/web/dist /ragflow/web/dist

COPY --from=builder /ragflow/VERSION /ragflow/VERSION
ENTRYPOINT ["./entrypoint.sh"]
