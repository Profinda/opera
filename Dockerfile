FROM ruby:3.2

MAINTAINER ProFinda Developers <dev@profinda.com>

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt-get update -y && \
    apt-get install -y cmake \
                       build-essential

ENV APP_HOME /usr/src/app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

COPY . $APP_HOME

RUN bundle install -j 8

COPY . $APP_HOME
