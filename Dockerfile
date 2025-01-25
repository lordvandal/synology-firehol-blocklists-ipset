FROM alpine:latest

RUN apk add --no-cache tini bash iptables iptables-legacy ipset iproute2 curl unzip grep gawk lsof perl && \
    mkdir /firehol /firehol-template
    
ARG IPRANGE_LATEST_VERSION=1.0.4
ARG FIREHOL_LATEST_VERSION=3.1.7

RUN apk add --no-cache --virtual .iprange_builddep autoconf automake make gcc musl-dev && \
    curl -L https://github.com/firehol/iprange/releases/download/v${IPRANGE_LATEST_VERSION}/iprange-${IPRANGE_LATEST_VERSION}.tar.gz | tar zvx -C /tmp && \
    cd /tmp/iprange-${IPRANGE_LATEST_VERSION}/ && \
    ./configure --prefix= --disable-man && \
    make && \
    make install && \
    cd && \
    rm -rf /tmp/iprange-${IPRANGE_LATEST_VERSION}/ && \
    apk del .iprange_builddep

RUN apk add --no-cache --virtual .firehol_builddep autoconf automake make && \
    curl -sL https://github.com/firehol/firehol/releases/download/v${FIREHOL_LATEST_VERSION}/firehol-${FIREHOL_LATEST_VERSION}.tar.gz | tar zvx -C /tmp && \
    cd /tmp/firehol-${FIREHOL_LATEST_VERSION}/ && \
    ./autogen.sh && \
    ./configure --prefix= --disable-doc --disable-man && \
    make && \
    make install && \
    cd && \
    rm -rf /tmp/firehol-${FIREHOL_LATEST_VERSION}/ && \
    apk del .firehol_builddep

# Blacklists separated by one space
# Default blacklists: Firehol level 1, 2 and 3 lists from https://iplists.firehol.org/
#ENV URLS="https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset"
ENV URLS=https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset

# Default iptables chain name
ENV CHAIN="INPUT"

# Default ipset set names
ENV IPSET="firehol-blocklist"
ENV IPSET_TMP="firehol-blocklist-tmp"

# Default cache file with the latest version of the ipset
#CACHE_FILE="/firehol/firehol.blocklist.cache"

# Default local block list file
#LOCAL_BLACKLIST_FILE="/firehol/blocklist"

# Default local white list file
#LOCAL_WHITELIST_FILE="/firehol/whitelist"

COPY firehol.blocklist.cache blocklist whitelist /firehol-template
COPY run.sh firehol-blocklists.sh /bin
RUN chmod +x /bin/run.sh /bin/firehol-blocklists.sh

VOLUME ["/firehol"]

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/run.sh"]
