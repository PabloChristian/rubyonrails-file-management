source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.5.1'
gem 'rails', '~> 5.2.1'
gem 'pg', '>= 0.18', '< 2.0'
#gem 'mysql2'
gem 'puma', '~> 3.11'
gem 'rack-cors'
gem 'rack-attack'
gem 'swagger-blocks'
gem 'jwt'
gem 'rubocop', require: false
gem 'active_model_serializers'
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false
gem "paperclip", "~> 6.1.0"
gem 'aws-sdk-s3'
gem 'kaminari'
gem 'nokogiri', '~> 1.10', '>= 1.10.1'
gem 'bunny'
gem 'sneakers'
gem 'rubyzip'
gem 'foreman'
group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails', '~>3.8'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-matchers', '4.0.0.rc1'
  gem 'shoulda-callback-matchers', '~> 1.1.1'
  gem 'rails-controller-testing' # If you are using Rails 5.x
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
