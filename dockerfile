FROM hadoop-preinstall:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    net-tools \
    && apt-get clean

# Hadoop version
ENV HADOOP_VERSION=3.4.0
ENV HADOOP_HOME=/opt/hadoop
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Download Hadoop
RUN tar -xzf hadoop-${HADOOP_VERSION}.tar.gz && \
    mv hadoop-${HADOOP_VERSION} $HADOOP_HOME && \
    rm hadoop-${HADOOP_VERSION}.tar.gz

# SSH setup (important for multi-node)
RUN ssh-keygen -A && \
    mkdir /root/.ssh && \
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
# Copy configs
COPY config/* $HADOOP_HOME/etc/hadoop/

# Format script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 9870 8088 9000

CMD ["/start.sh"]