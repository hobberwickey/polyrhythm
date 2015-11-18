require 'active_record'

Dir[File.dirname(__FILE__) + "/../lib/api.rb"].each { |file| require file }
Dir[File.dirname(__FILE__) + "/../models/*.rb"].each { |file| require file }
    
namespace :api do
  task(:environment) do
    ActiveRecord::Base.establish_connection ENV['DATABASE_URL']
  end

  desc 'Auto Generates a simple API'
  task :generate_routes => :environment do
    File.open("#{Dir.pwd}/lib/api/generated_routes.rb", 'w') do |f|
      f.puts "class Application < Sinatra::Base" 
    
      ActiveRecord::Base.descendants.each do |model|
        next if model.ignore_self
        
        puts "Creating Routes for #{model.name}"

        f.puts "  ###########################"
        f.puts "  # #{model.name}"
        f.puts "  ###########################"
        f.puts ""

        #Generate Custom Actions
        f.puts "  #Generated custom actions for #{model.name}"
        f.puts ""
        
        model.custom_actions.each do |k, v|
          f.puts "  #{v[:method].downcase} '#{v[:href]}' do"
          if model.restricted_actions[k].present?  
            f.puts "    status 401 and return unless has_access? #{model.restricted_actions[k].map { |a| ':' + a.to_s }.join(', ')}"
          end
          f.puts "    siren #{model.name}.api_scope(@current_user, '#{k}').#{v[:action]}(params, @current_user)"
          f.puts "  end"
          f.puts ""
        end

        model.custom_serializers.each do |name, action|
          action.each do |k, v| 
            f.puts "  #{v[:method].downcase} '#{v[:href]}' do"
            # if model.restricted_actions[k].present?  
            #   f.puts "    status 401 and return unless has_access? #{model.restricted_actions[k].map { |a| ':' + a.to_s }.join(', ')}"
            # end
            f.puts "    siren #{model.name}.api_scope(@current_user, '#{v[:name]}').#{v[:action]}(params, @current_user)"
            f.puts "  end"
            f.puts ""
          end
        end

        unless model.ignored_actions.include?(:index)
          #For priming API client. Gets a list of actions available to the user
          f.puts "  #Priming for #{model.name}"
          f.puts "  get '/#{model.table_name}/prime' do"
          if model.restricted_actions[:prime].present?  
            f.puts "    status 401 and return unless has_access? #{model.restricted_actions[:prime].map { |a| ':' + a.to_s }.join(', ')}"
          end
          f.puts "    siren_prime #{model.name}.api_scope(@current_user, :prime)"
          f.puts "  end"
          f.puts ""
        end

        unless model.ignored_actions.include?(:index)
          #Generate Primary Collection Routes
          f.puts "  #Get Pagination collection for #{model.name}"
          f.puts "  get '/#{model.table_name}' do"
          if model.restricted_actions[:index].present?  
            f.puts "    status 401 and return unless has_access? #{model.restricted_actions[:index].map { |a| ':' + a.to_s }.join(', ')}"
          end
          f.puts "    siren #{model.name}.api_scope(@current_user, :index).paginate(:page => params[:page], :per_page => params[:per_page])"
          f.puts "  end"
          f.puts ""
        end
        
        unless model.ignored_actions.include?(:show)
          #Generate Show Routes
          f.puts "  #Show #{model.name}"
          f.puts "  get '/#{model.table_name}/:id' do"
          if model.restricted_actions[:show].present?  
            f.puts "    status 401 and return unless has_access? #{model.restricted_actions[:show].map { |a| ':' + a.to_s }.join(', ')}"
          end
          f.puts "    siren #{model.name}.api_scope(@current_user, :show).find(params[:id])"
          f.puts "  end"
          f.puts ""
        end

        unless model.ignored_actions.include?(:create)
          #Generate Creation Routes
          f.puts "  #Create #{model.name}"
          f.puts "  post '/#{model.table_name}' do"
          if model.restricted_actions[:create].present?  
            f.puts "    status 401 and return unless has_access? #{model.restricted_actions[:create].map { |a| ':' + a.to_s }.join(', ')}"
          end
          f.puts "    item = #{model.name}.api_scope(@current_user, :create).new(params[:#{model.table_name}])"
          f.puts "    item.send('#{model.api.callbacks[:before_create]}', @current_user)" unless model.api.callbacks[:before_create].blank?
          f.puts "    if item.save!"
          f.puts "      status 200"
          f.puts "      item.send('#{model.api.callbacks[:after_create]}', @current_user)" unless model.api.callbacks[:after_create].blank?
          f.puts "    else"
          f.puts "      status 500"
          f.puts "    end"
          f.puts "  end"
          f.puts ""
        end
        
        unless model.ignored_actions.include?(:update)        
          #Generate Update Routes
          f.puts "  #Update #{model.name}"
          f.puts "  put '/#{model.table_name}/:id' do"
          if model.restricted_actions[:update].present?  
            f.puts "    status 401 and return unless has_access? #{model.restricted_actions[:update].map { |a| ':' + a.to_s }.join(', ')}"
          end
          f.puts "    item = #{model.name}.api_scope(@current_user, :update).find(params[:id])"
          f.puts "    item.send('#{model.api.callbacks[:before_update]}', @current_user)" unless model.api.callbacks[:before_update].blank?
          f.puts "    if item.update_attributes(params[:#{model.table_name}])"
          f.puts "      status 200"
          f.puts "      item.send('#{model.api.callbacks[:after_update]}', @current_user)" unless model.api.callbacks[:after_update].blank?
          f.puts "    else"
          f.puts "      status 500"
          f.puts "    end"
          f.puts "  end"
          f.puts ""
        end

        unless model.ignored_actions.include?(:destroy)
          #Generate Delete Routes
          f.puts "  #DELETE #{model.name}"
          f.puts "  delete '/#{model.table_name}/:id' do"
          if model.restricted_actions[:destroy].present?  
            f.puts "    status 401 and return unless has_access? #{model.restricted_actions[:destroy].map { |a| ':' + a.to_s }.join(', ')}"
          end
          f.puts "    item = #{model.name}.api_scope(@current_user, :destroy).find(params[:id])"
          f.puts "    item.send('#{model.api.callbacks[:before_destroy]}', @current_user)" unless model.api.callbacks[:before_destroy].blank?
          f.puts "    if item.destroy"
          f.puts "      status 200"
          f.puts "    item.send('#{model.api.callbacks[:after_destroy]}', @current_user)" unless model.api.callbacks[:after_destroy].blank?
          f.puts "    else"
          f.puts "      status 500"
          f.puts "    end"
          f.puts "  end"
          f.puts ""
        end

        #Generated Assiciation Routes
        f.puts "  #Generated association routes for #{model.name}"
        model.reflections.each do |r|
          unless model.ignored_associations.include?(r[0].to_sym)
            f.puts "  get '/#{model.table_name}/:id/#{r[0]}' do"
            if model.restricted_associations[r[0].to_sym].present?  
              f.puts "    status 401 and return unless has_access? #{model.restricted_associations[r[0].to_sym].map { |a| ':' + a.to_s }.join(', ')}"
            end
            f.puts "    siren #{model.name}.api_associations params[:id], '#{r[0]}', @current_user"
            f.puts "  end"
            f.puts ""
          end
        end  

        f.puts ""
      end

      f.puts "end"
      f.close
    end
  end
end
