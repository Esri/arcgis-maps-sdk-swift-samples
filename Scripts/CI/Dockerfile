FROM alpine:latest
MAINTAINER Ting Chen <tchen@esri.com>
ENV PYTHONUNBUFFERED=1

# Add scripts for the check.
ADD entry.py /entry.py
ADD common.py /common.py
ADD style.rb /style.rb
ADD metadata_checker.py /metadata_checker.py
ADD readme_checker.py /readme_checker.py

# Install dependencies.
RUN echo "**** Install Ruby and mdl ****" && \
    apk add --update --no-cache ruby-full && \
    gem install mdl --no-document && \
    echo "**** Install Python ****" && \
    apk add --no-cache python3 && \
    if [ ! -e /usr/bin/python ]; then ln -sf python3 /usr/bin/python ; fi
ENTRYPOINT ["python3", "/entry.py"]