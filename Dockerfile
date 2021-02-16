# Use Ruby 2.7.2 as base image
FROM ruby:2.7.2

# Prevent bundler warnings
RUN gem install bundler

# Install all Ruby dependencies
RUN bundle install --full-index