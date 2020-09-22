web: bundle exec puma -p $PORT
worker: bundle exec sidekiq -t 25 -r ./app/lib/workers.rb