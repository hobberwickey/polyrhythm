require 'active_record'

namespace :db do
  task(:environment) do
    ActiveRecord::Base.establish_connection ENV['DATABASE_URL']
  end

  desc 'Migrates the schema (options: VERSION=x, VERBOSE=false)'
  task :migrate => :environment do
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate "#{File.dirname(__FILE__)}/../db/migrate", ENV['VERSION'] ? ENV['VERSION'].to_i : nil
  end

  desc 'Rolls the schema back (specify steps w/ STEP=n).'
  task :rollback => :environment do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.rollback "#{File.dirname(__FILE__)}/../db/migrate", ENV['VERSION'] ? ENV['VERSION'].to_i : step
  end
end
