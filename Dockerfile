# ΓRF client
FROM ubuntu:xenial

RUN apt update
RUN apt install -y wget git build-essential cmake gpsd gpsd-clients libusb-1.0-0-dev \
 vim librtlsdr-dev python3-dev python3-pip pkg-config libfftw3-dev libhackrf-dev \
 git curl

RUN git clone -b es-gammarf https://github.com/sofwerx/gammarf /gammarf

WORKDIR /gammarf

# hackrf
RUN curl -sL https://github.com/mossmann/hackrf/releases/download/v2017.02.1/hackrf-2017.02.1.tar.xz | tar xJf - -C /tmp \
 && cd /tmp/hackrf-2017.02.1/host \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make \
 && make install \
 && ldconfig \
 && cd /tmp \
 && rm -fr hackrf-2017.02.1

# rtl-sdr
RUN git clone https://github.com/keenerd/rtl-sdr /tmp/rtl-sdr \
 && cd /tmp/rtl-sdr \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make \
 && make install \
 && cd /tmp \
 && rm -fr /tmp/rtl-sdr

RUN cd /gammarf/3rdparty/librtlsdr-2freq \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make \
 && make install

# tpms
RUN git clone https://github.com/merbanan/rtl_433 /tmp/rtl_433 \
 && cd /tmp/rtl_433 \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make \
 && make install \
 && cd /tmp \
 && rm -fr /tmp/rtl_433

RUN pip3 install --upgrade pip
RUN pip3 install -r /gammarf/requirements.txt

RUN chmod +x /gammarf/gammarf.py
ENV PYTHONIOENCODING UTF-8

# Prepare golang for gotty

# gcc for cgo
RUN apt-get update && apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
	&& rm -rf /var/lib/apt/lists/*

ENV GOLANG_VERSION 1.9.4

RUN set -eux; \
	\
# this "case" statement is generated via "update.sh"
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64) goRelArch='linux-amd64'; goRelSha256='15b0937615809f87321a457bb1265f946f9f6e736c563d6c5e0bd2c22e44f779' ;; \
		armhf) goRelArch='linux-armv6l'; goRelSha256='3c8cf3f79754a9fd6b33e2d8f930ee37d488328d460065992c72bc41c7b41a49' ;; \
		arm64) goRelArch='linux-arm64'; goRelSha256='41a71231e99ccc9989867dce2fcb697921a68ede0bd06fc288ab6c2f56be8864' ;; \
		i386) goRelArch='linux-386'; goRelSha256='d440aee90dad851630559bcee2b767b543ce7e54f45162908f3e12c3489888ab' ;; \
		ppc64el) goRelArch='linux-ppc64le'; goRelSha256='8b25484a7b4b6db81b3556319acf9993cc5c82048c7f381507018cb7c35e746b' ;; \
		s390x) goRelArch='linux-s390x'; goRelSha256='129f23b13483b1a7ccef49bc4319daf25e1b306f805780fdb5526142985edb68' ;; \
		*) goRelArch='src'; goRelSha256='0573a8df33168977185aa44173305e5a0450f55213600e94541604b75d46dc06'; \
			echo >&2; echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding Go binary release; will be building from source"; echo >&2 ;; \
	esac; \
	\
	url="https://golang.org/dl/go${GOLANG_VERSION}.${goRelArch}.tar.gz"; \
	wget -O go.tgz "$url"; \
	echo "${goRelSha256} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ "$goRelArch" = 'src' ]; then \
		echo >&2; \
		echo >&2 'error: UNIMPLEMENTED'; \
		echo >&2 'TODO install golang-any from jessie-backports for GOROOT_BOOTSTRAP (and uninstall after build)'; \
		echo >&2; \
		exit 1; \
	fi; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

# Build gotty
RUN go get github.com/yudai/gotty

ENV GAMMARF_ELASTICSEARCH_URL=http://localhost:9200/gammarf/rf GAMMARF_ELASTICSEARCH_USERNAME=elastic GAMMARF_ELASTICSEARCH_PASSWORD=elastic GAMMARF_STATION_ID=demo GAMMARF_STATION_PASS=demo1234

RUN apt-get update
RUN apt-get install -y usbutils tmux

WORKDIR /gammarf

RUN pip3 install requests elasticsearch

ADD gammarf.sh /gammarf.sh
ADD gammarf_connector.py /gammarf/modules/gammarf_connector.py

CMD /gammarf.sh

