##################################################################
#                       INTERMEDIATE BUILD IMAGE
##################################################################
from alpine as build-environment

WORKDIR /opt

# Install Rust via rustup installer (see https://rustup.rs)
RUN apk add clang lld curl build-base linux-headers git \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > rustup.sh \
    && chmod +x ./rustup.sh \
    && ./rustup.sh -y

# Compile tools within Foundry toolkit
# Note: strip is used to reduce non-essential information from compiled files
# See: https://www.computerhope.com/unix/strip.htm
WORKDIR /opt/foundry
COPY . .
RUN source $HOME/.profile && cargo build --release \
    && strip /opt/foundry/target/release/forge \
    && strip /opt/foundry/target/release/cast \
    && strip /opt/foundry/target/release/anvil

##################################################################
#                      FINAL IMAGE WITH EXECUTABLE
##################################################################
from alpine as foundry-client

# Retrieve glibc apk as glibc is a dependency that isn't included in the binary
# See: https://github.com/sgerrand/alpine-pkg-glibc 
ENV GLIBC_KEY=https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
ENV GLIBC_KEY_FILE=/etc/apk/keys/sgerrand.rsa.pub
ENV GLIBC_RELEASE=https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r0/glibc-2.35-r0.apk
RUN apk add linux-headers gcompat
RUN wget -q -O ${GLIBC_KEY_FILE} ${GLIBC_KEY} \
    && wget -O glibc.apk ${GLIBC_RELEASE} \
    && apk add glibc.apk --force

# Extract built Foundry tools from intermediate build image
COPY --from=build-environment /opt/foundry/target/release/forge /usr/local/bin/forge
COPY --from=build-environment /opt/foundry/target/release/cast /usr/local/bin/cast
COPY --from=build-environment /opt/foundry/target/release/anvil /usr/local/bin/anvil
ENTRYPOINT ["/bin/sh", "-c"]