FROM hadoop-preinstall:latest

# Installer dépendances
RUN apt-get update && apt-get install -y \
    curl \
    net-tools \
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

USER hadoop
WORKDIR /home/hadoop

# SSH sans mot de passe
RUN ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Copier config Hadoop
COPY config/* $HADOOP_HOME/etc/hadoop/

# Script de démarrage
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]