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

  def self.instance_to_siren( obj, request, user=nil, to_json: true )
    siren = {
      :class => [ obj.class.table_name, "item" ],
      :properties => obj.role_attributes(user).select { |k, v| !obj.class.ignored_attributes.include? k.to_sym },
      :entities => [],
      :actions => obj.get_actions(user),
      :links => [ { :rel => [ "self" ], :href => request.fullpath + request.query_string }]
    }

    obj.class.included_methods.each do |k, v|
      siren[:properties][k] = obj.send(v)
    end

    obj.role_reflections(user).each do |k, v|
      entity = {
        :class => [k, v.macro],
        :entities => []
      }

      rel = obj.send(k)

      if (v.macro == :belongs_to || v.macro == :has_one)
        entity[:rel] = ["item"]
        entity[:href] = "/#{obj.class.table_name}/#{obj.id}/#{k}"

        if rel.present?
          entity[:properties] = rel.attributes.select { |k, v| !rel.class.ignored_attributes.include? k.to_sym }

          rel.class.included_methods.each do |k, v|
            entity[:properties][k] = rel.send(v)
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

    to_json ? siren.to_json : siren
  end

  def self.relation_to_siren( obj, request, user=nil, to_json: true )
    siren = {
      :class => [ obj.table_name, "collection" ],
      :entities => [],
      :properties => { :total_pages =>  obj.try(:total_pages) },
      :actions => obj.get_actions(user),
      :links => [ { :rel => ["self"], :href => request.fullpath + request.query_string } ]
    }

    action_cache = nil
    obj.each do |item|
      actions = action_cache || item.get_actions(user)

      href = Api::Utils::get_href(item)

      entity = {
        :class => [ obj.name.pluralize.downcase, "item" ],
        :rel => [ "item" ],
        :properties => item.role_attributes(user).select { |k, v| !obj.ignored_attributes.include? k.to_sym },
        :entities => [],
        :actions => actions,
        :links => [
          { :rel => ["self"], :href => href }
        ]
      }

      obj.included_methods.each do |k, v|
        entity[:properties][k] = item.send(v)
      end

      item.role_reflections(user).each do |k, v|
        sub_entity = {
          :class => [k, v.macro],
          :entities => []
        }

        rel = item.send(k)
        if v.macro == :belongs_to || v.macro == :has_one
          sub_entity[:rel] = ["item"]
          sub_entity[:href] = "/#{item.class.table_name}/#{item.id}/#{k}"

          if rel.present?
            sub_entity[:properties] = rel.attributes.select { |k, v| !rel.class.ignored_attributes.include? k.to_sym }

            rel.class.included_methods.each do |k, v|
              sub_entity[:properties][k] = rel.send(v)
            end
          else
            sub_entity[:properties] = {}
          end
        else
          sub_entity[:rel] = ["collection"]
          sub_entity[:href] = "/#{item.class.table_name}/#{item.id}/#{k}"
          sub_entity[:properties] = {}
        end

        entity[:entities] << sub_entity
      end

      siren[:entities] << entity
    end

    to_json ? siren.to_json : siren
  end
end