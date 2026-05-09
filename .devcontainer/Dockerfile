FROM ruby:3.2-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libssl-dev \
      libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY Gemfile rubymap.gemspec ./
COPY lib/rubymap/version.rb ./lib/rubymap/

RUN bundle install

COPY . .
