FROM alpine:latest

ARG IPRANGE_LATEST_VERSION=$(curl -s https://api.github.com/repos/firehol/iprange/releases/latest | grep "tag_name" | cut -d'v' -f2 | cut -d'"' -f1)
ARG FIREHOL_LATEST_VERSION=$(curl -s https://api.github.com/repos/firehol/firehol/releases/latest | grep "tag_name" | cut -d'v' -f2 | cut -d'"' -f1)

RUN apk add --no-cache tini bash iptables iptables-legacy ipset iproute2 curl unzip grep gawk lsof && \
    mkdir /firehol /firehol-template

RUN apk add --no-cache --virtual .iprange_builddep autoconf automake make gcc musl-dev && \
    curl -L https://github.com/firehol/iprange/releases/download/v${IPRANGE_LATEST_VERSION}/iprange-${IPRANGE_LATEST_VERSION}.tar.gz | tar zvx -C /tmp && \
    cd /tmp/iprange-1.0.4/ && \
    ./configure --prefix= --disable-man && \
    make && \
    make install && \
    cd && \
    rm -rf /tmp/iprange-1.0.4/ && \
    apk del .iprange_builddep

RUN apk add --no-cache --virtual .firehol_builddep autoconf automake make && \
    curl -L https://github.com/firehol/firehol/releases/download/v${FIREHOL_LATEST_VERSION}/firehol-${FIREHOL_LATEST_VERSION}.tar.gz | tar zvx -C /tmp && \
    cd /tmp/firehol-3.1.7/ && \
    ./autogen.sh && \
    ./configure --prefix= --disable-doc --disable-man && \
    make && \
    make install && \
    cd && \
    rm -rf /tmp/firehol-3.1.7/ && \
    apk del .firehol_builddep

# ENV variables
# (note: ENV is one long line to minimise layers)
ENV \
  # Blacklists separated by one space
  # Default blacklists: Firehol level 1, 2 and 3 lists from https://iplists.firehol.org/
  URLS="https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset" \

  # Default cache file with the latest version of the ipset
  #CACHE_FILE="/firehol/firehol.blocklist.cache" \

  # Default local block list file
  #LOCAL_BLACKLIST_FILE="/firehol/blocklist" \

  # Default local white list file
  #LOCAL_WHITELIST_FILE="/firehol/whitelist" \

  # Default iptables chain name
  CHAIN="INPUT" \

  # Default ipset set names
  IPSET="firehol-blocklist" \
  IPSET_TMP="firehol-blocklist-tmp"

COPY firehol.blocklist.cache blocklist whitelist /firehol-template
COPY run.sh firehol-blocklists.sh /bin
RUN chmod +x /bin/run.sh /bin/firehol-blocklists.sh

VOLUME ["/firehol"]

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/run.sh"]
