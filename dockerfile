FROM hadoop-preinstall:latest

# Installer dépendances
RUN apt-get update && apt-get install -y \
    curl \
    net-tools \
    sudo \
    openssh-server \
    openssh-client \
    && apt-get clean

# Variables Hadoop
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Télécharger Hadoop
RUN tar -xzf hadoop-$HADOOP_VERSION.tar.gz \
    && mv hadoop-$HADOOP_VERSION $HADOOP_HOME \
    && rm hadoop-$HADOOP_VERSION.tar.gz

# Config SSH
RUN ssh-keygen -A

RUN useradd -ms /bin/bash hadoop
RUN echo "hadoop:hadoop" | chpasswd
RUN adduser hadoop sudo

# Pre-create directories with correct ownership
RUN mkdir -p $HADOOP_HOME/logs && \
    mkdir -p /run/sshd && \
    chown -R hadoop:hadoop $HADOOP_HOME && \
    chmod 755 /run/sshd

# Allow hadoop user to start SSH without password
RUN echo "hadoop ALL=(ALL) NOPASSWD: /etc/init.d/ssh" >> /etc/sudoers

# Copier config Hadoop
COPY config-hadoop/* $HADOOP_HOME/etc/hadoop/

# Script de démarrage
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Persist env vars for SSH sessions (Hadoop scripts source hadoop-env.sh)
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo "export HADOOP_HOME=/opt/hadoop" >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> /opt/hadoop/etc/hadoop/hadoop-env.sh

# SSH configuration for hadoop user
RUN mkdir -p /home/hadoop/.ssh && \
    ssh-keygen -t rsa -P "" -f /home/hadoop/.ssh/id_rsa && \
    cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys && \
    chmod 600 /home/hadoop/.ssh/authorized_keys && \
    chown -R hadoop:hadoop /home/hadoop/.ssh && \
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /home/hadoop/.bashrc && \
    echo "export HADOOP_HOME=/opt/hadoop" >> /home/hadoop/.bashrc && \
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> /home/hadoop/.bashrc

USER hadoop
WORKDIR /home/hadoop

CMD ["/start.sh"]