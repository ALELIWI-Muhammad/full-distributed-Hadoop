FROM hadoop-preinstall:latest

# Installer dépendances (SSH supprimé — authentification via Kerberos)
# libpam-krb5 est intentionnellement absent : il ferait échouer chpasswd
# car PAM tenterait de valider le mot de passe via le KDC (inexistant au build)
RUN apt-get update && apt-get install -y \
    curl \
    net-tools \
    netcat-openbsd \
    sudo \
    krb5-user \
    krb5-config \
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

# Créer l'utilisateur hadoop
# Utiliser -p avec un hash précompilé pour éviter que PAM ne bloque chpasswd
# (le hash correspond au mot de passe "hadoop")
RUN useradd -ms /bin/bash -p $(openssl passwd -6 hadoop) hadoop
RUN adduser hadoop sudo

# Pré-créer les répertoires avec les bonnes permissions
RUN mkdir -p $HADOOP_HOME/logs && \
    mkdir -p /etc/hadoop/keytabs && \
    chown -R hadoop:hadoop $HADOOP_HOME && \
    chown hadoop:hadoop /etc/hadoop/keytabs && \
    chmod 755 $HADOOP_HOME/logs

# Copier config Hadoop
COPY config-hadoop/* $HADOOP_HOME/etc/hadoop/

# Copier la configuration Kerberos (krb5.conf sera monté via volume)
COPY config-kerberos/krb5.conf /etc/krb5.conf

# Script de démarrage
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Scripts TP Kerberos
COPY tp-scripts/ /tp-scripts/
RUN chmod +x /tp-scripts/*.sh

# Persist environment variables for Hadoop sessions
# Disable Kerberos reverse DNS to prevent Docker network suffix from breaking principal matching
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo "export HADOOP_HOME=/opt/hadoop" >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo "export HADOOP_OPTS=\"-Djava.security.krb5.conf=/etc/krb5.conf -Dsun.security.krb5.disableReferrals=true \$HADOOP_OPTS\"" >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo "export HADOOP_NAMENODE_OPTS=\"-Dsun.net.spi.nameservice.provider.1=default \$HADOOP_NAMENODE_OPTS\"" >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo "export HADOOP_DATANODE_OPTS=\"-Dsun.net.spi.nameservice.provider.1=default \$HADOOP_DATANODE_OPTS\"" >> /opt/hadoop/etc/hadoop/hadoop-env.sh

# Variables d'environnement pour l'utilisateur hadoop
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /home/hadoop/.bashrc && \
    echo "export HADOOP_HOME=/opt/hadoop" >> /home/hadoop/.bashrc && \
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> /home/hadoop/.bashrc && \
    echo "export KRB5_CONFIG=/etc/krb5.conf" >> /home/hadoop/.bashrc

# Rester en root pour le CMD : l'entrypoint fixe les permissions des volumes
# puis bascule sur l'utilisateur hadoop via exec su
USER root
WORKDIR /home/hadoop

CMD ["/start.sh"]
