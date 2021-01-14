# Set the base image
FROM golang:buster

# By-pass all interaction message
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt update \
    && apt install -y \
        python3 \
        python3-pip \
        groff \
        less \
        mime-support \
        curl \
        bash \
        gnupg \
        coreutils \
        gzip \
        git \
        wget \
	lsb-release \
        gnupg \
    && pip3 install --upgrade six awscli s3cmd python-magic crcmod

# Install MySql client
ARG MYSQL_VERSION=0.8.16-1
RUN wget https://dev.mysql.com/get/mysql-apt-config_${MYSQL_VERSION}_all.deb \
	&& dpkg -i mysql-apt-config_${MYSQL_VERSION}_all.deb \
	&& rm -f mysql-apt-config_${MYSQL_VERSION}_all.deb
RUN apt update \
	&& apt install -y mysql-client \
	&& apt clean all

# Set Default Environment Variables
ENV BACKUP_CREATE_DATABASE_STATEMENT=false
ENV TARGET_DATABASE_PORT=3306
ENV SLACK_ENABLED=false
ENV SLACK_USERNAME=kubernetes-s3-mysql-backup
ENV CLOUD_SDK_VERSION=319.0.0
# Release commit for https://github.com/FiloSottile/age/releases/tag/v1.0.0-beta5 / https://github.com/FiloSottile/age/commit/31500bfa2f6a36d2958483fc54d6e3cc74154cbc
ENV AGE_VERSION=31500bfa2f6a36d2958483fc54d6e3cc74154cbc
ENV BACKUP_PROVIDER=aws

# Install FiloSottile/age (https://github.com/FiloSottile/age)
RUN git clone https://filippo.io/age \
    && cd age \
    && git checkout $AGE_VERSION \
    && go build -o . filippo.io/age/cmd/... \
    && cp age /usr/local/bin/ \
    && cd .. \
    && rm -rf age

# Set Google Cloud SDK Path
ENV PATH /go/google-cloud-sdk/bin:$PATH

# Install Google Cloud SDK
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    gcloud --version

# Copy Slack Alert script and make executable
COPY resources/slack-alert.sh /
RUN chmod +x /slack-alert.sh

# Copy backup script and execute
COPY resources/perform-backup.sh /
RUN chmod +x /perform-backup.sh
CMD ["/bin/bash", "/perform-backup.sh"]
