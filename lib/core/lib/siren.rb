module Siren
  def self.map(request, user=nil)
    map = {
      tables: {},
      roles: user.blank? ? [] : user.roles.pluck(:name)
    }

    ActiveRecord::Base.descendants.each do |obj|
      next if obj.ignore_self

      map[:tables][obj.table_name.to_sym] = {
        :class => [ obj.table_name ],
        :entities => [],
        :properties => {},
        :actions => obj.get_actions(user) + ( obj.first.present? ? obj.first.get_actions(user) : [] ),
        :links => [ { :rel => ["self"], :href => request.fullpath + request.query_string } ]
      }
    end

    return map.to_json
  end

  def self.prime( obj, request, user=nil )
    siren = {
      :class => [ obj.table_name ],
      :entities => [],
      :properties => {},
      :actions => obj.get_actions(user) + ( obj.first.present? ? obj.first.get_actions(user) : [] ),
      :links => [ { :rel => ["self"], :href => request.fullpath + request.query_string } ]
    }

    return siren.to_json
  end

  def self.instance_to_siren( obj, request, user=nil )
    roles = user.try(:roles) || [:public]
    model = obj.class
    api = model.api

    restricted_actions, restricted_attributes, restricted_associations = api.role_restrictions(roles)
    custom_actions, custom_attributes, custom_serializers = api.customizations

    siren = {
      :class => [ model.table_name, "item" ],
      :properties => obj.attributes.select { |k,v| !restricted_attributes.include? k.to_sym },
      :entities => [],
      :actions => api.default_actions.merge(custom_actions)
                    .select { |k,v| (!restricted_actions.include? k.to_sym) && (v[:for] == "item") }
                    .map { |k,v| v.select { |_k, _v| ![:calls].include? _k } },
      :links => [ { :rel => [ "self" ], :href => request.fullpath + request.query_string }]
    }

    custom_attributes.each do |k, v|
      siren[:properties][k] = obj.send(v) unless restricted_attributes.include? k.to_sym
    end

    obj.class.reflections.each do |k, v|
      next if restricted_associations.include? k.to_sym

      entity = {
        :class => [k, v.macro],
        :entities => []
      }

      rel = obj.send(k)

      if (v.macro == :belongs_to || v.macro == :has_one)
        entity[:rel] = ["item"]
        entity[:href] = "/#{obj.class.table_name}/#{obj.id}/#{k}"

        if rel.present?
          restricted_rel_actions, restricted_rel_attributes, restricted_rel_associations = rel.class.api.role_restrictions(roles)
          custom_rel_actions, custom_rel_attributes, custom_rel_serializers = rel.class.api.customizations
          
          entity[:properties] = rel.attributes.select { |k, v| !restricted_rel_attributes.include? k.to_sym }

          custom_rel_attributes.each do |k, v|
            entity[:properties][k] = rel.send(v) unless restricted_rel_attributes.include? k
          end
        else
          entity[:properties] = {}
        end
      else
        entity[:rel] = ["collection"]
        entity[:href] = "/#{obj.class.table_name}/#{obj.id}/#{k}"
        entity[:properties] = {}
      end

      siren[:entities] << entity
    end

    siren.to_json
  end

  def self.relation_to_siren( obj, request, user=nil, to_json: true )
    roles = user.try(:roles) || [:public]
    api = obj.api

    restricted_actions, restricted_attributes, restricted_associations = api.role_restrictions(roles)
    custom_actions, custom_attributes, custom_serializers = api.customizations

    collection_actions = api.default_actions.merge(custom_actions)
                          .select { |k,v| !restricted_actions.include? k.to_sym && v[:for] == "collection" }
                          .map { |k,v| v.select { |_k, _v| ![:calls, :for].include? _k } }

    item_actions = api.default_actions.merge(custom_actions)
                    .select { |k,v| !restricted_actions.include? k.to_sym && v[:for] == "item" }
                    .map { |k,v| v.select { |_k, _v| ![:calls, :for].include? _k } }

    siren = {
      :class => [ obj.table_name, "collection" ],
      :entities => [],
      :properties => { :total_pages =>  obj.try(:total_pages) },
      :actions => collection_actions,
      :links => [ { :rel => ["self"], :href => request.fullpath + request.query_string } ]
    }

    obj.each do |item|
      entity = {
        :class => [ obj.name.pluralize.downcase, "item" ],
        :rel => [ "item" ],
        :properties => item.attributes.select { |k,v| !restricted_attributes.include? k.to_sym },
        :entities => [],
        :actions => item_actions,
        :links => [
          { :rel => ["self"], :href => "/#{item.class.table_name}/#{item.id}" }
        ]
      }

      custom_attributes.each do |k, v|
        siren[:properties][k] = item.send(v) unless restricted_attributes.include? k.to_sym
      end

      obj.reflections.each do |k, v|
        next if restricted_associations.include? k.to_sym
        
        sub_entity = {
          :class => [k, v.macro],
          :entities => []
        }

        rel = item.send(k)
        if (v.macro == :belongs_to || v.macro == :has_one)
          sub_entity[:rel] = ["item"]
          sub_entity[:href] = "/#{item.class.table_name}/#{item.id}/#{k}"

          if rel.present?
            restricted_rel_actions, restricted_rel_attributes, restricted_rel_associations = rel.class.api.role_restrictions(roles)
            custom_rel_actions, custom_rel_attributes, custom_rel_serializers = rel.class.api.customizations
            
            sub_entity[:properties] = rel.attributes.select { |k, v| !restricted_rel_attributes.include? k.to_sym }

            custom_rel_attributes.each do |k, v|
              sub_entity[:properties][k] = rel.send(v) unless restricted_rel_attributes.include? k
            end
          else
            sub_entity[:properties] = {}
          end
        else
          sub_entity[:rel] = ["collection"]
          sub_entity[:href] = "/#{obj.table_name}/#{item.id}/#{k}"
          sub_entity[:properties] = {}
        end

        entity[:entities] << sub_entity
      end

      siren[:entities] << entity
    end

    to_json ? siren.to_json : siren
  end
end
