FROM quay.io/wakaba/docker-perl-app-base

ADD Makefile /app/
ADD config/ /app/config/
ADD bin/ /app/bin/
ADD lib/ /app/lib/
ADD modules/ /app/modules/
ADD icons/ /app/icons/
ADD *.html /app/
ADD *.css /app/
ADD *.cgi /app/
ADD *.png /app/
ADD *.txt /app/
ADD *.js /app/
ADD *.xml /app/
ADD *.u8 /app/
ADD *.pl /app/

RUN cd /app && \
    make deps-docker PMBP_OPTIONS="--execute-system-package-installer --dump-info-file-before-die" && \
    echo '#!/bin/bash' > /server && \
    echo 'export LANG=C' >> /server && \
    echo 'export TZ=UTC' >> /server && \
    echo 'port=${PORT:-8080}' >> /server && \
    echo 'cd /app && ./plackup -p ${port} -s Twiggy::Prefork bin/server.psgi' >> /server && \
    chmod u+x /server && \
    rm -rf /var/lib/apt/lists/* /app/local/pmbp/tmp /app/deps

CMD ["/server"]

## License: Public Domain.
