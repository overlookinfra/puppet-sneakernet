FROM alpine
MAINTAINER Ben Ford <ben.ford@puppet.com>
WORKDIR /tmp

RUN apk update                                                                                                                             \
        && apk add --no-cache ruby ruby-etc ruby-dev zlib-dev build-base                                                \
        && gem install eventmachine syck json thin puppet-sneakernet --no-doc                                                                            \
        && apk del --purge build-base                                                                                                      \
        && rm -rf `gem environment gemdir`/cache

CMD ["puppet-sneakernet"]
