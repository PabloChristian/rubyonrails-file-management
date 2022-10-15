FROM ruby:2.5.1-alpine3.7

# Minimal requirements to run a Rails app
RUN apk add --no-cache --update bash \
                                build-base \
                                linux-headers \
                                git \
                                postgresql-dev \
                                nodejs \
                                tzdata \
                                imagemagick \
                                && rm -rf /var/cache/apk/*

ENV APP_PATH /code/
WORKDIR $APP_PATH

# Different layer for gems installation
ADD Gemfile $APP_PATH
ADD Gemfile.lock $APP_PATH
RUN bundle install --jobs `expr $(cat /proc/cpuinfo | grep -c "cpu cores") - 1` --retry 3

# Copy the application into the container
COPY . $APP_PATH
EXPOSE 3000

ENTRYPOINT ["rails", "s"]