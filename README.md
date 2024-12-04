# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...


## Sync from staging to macbook
./script/rsync_from_staging.sh

scp omicron:/var/www/gmail_sandbox/Gemfile.lock .

## Sync from macbook to staging

cd /Users/timothyharrison/Dropbox/o/gmail_sandbox
./script/rsync_to_staging.sh

