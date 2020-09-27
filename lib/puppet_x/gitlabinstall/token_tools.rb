# rubocop:disable Style/Documentation, Style/ClassAndModuleChildren, Style/ClassAndModuleCamelCase
module Puppet_X
  module GitlabInstall
    def self.normalize_project_name(name)
      name.gsub(%r{^/|/$}, '')
    end

    def self.normalize_project_scope(scope)
      case scope
      when nil, :absent, 'absent'
        return nil
      when [nil], [:absent], ['absent']
        return []
      when Array
        return scope.map { |x| normalize_project_scope(x) }
      when String
        s = { 'name' => scope }
      else
        s = scope.map { |k, v| [k.to_s, v] }.to_h
      end

      actions = s['actions']
      name    = s['name']
      type    = s['type']

      s['name']    = normalize_project_name(name)
      s['type']    = type ? type.to_s : 'repository'
      s['actions'] = if actions
                       [actions].flatten
                                .map { |a| a.to_s }
                                .select { |x| ['*', 'delete', 'pull', 'push'].include?(x) }
                                .sort
                     else
                       ['pull', 'push']
                     end

      s
    end

    def self.check_project_name(name)
      name.is_a?(String) && normalize_project_name(name).split('/').all? { |x| x =~ %r{^[a-z0-9]+((?:[._]|__|[-]*)[a-z0-9]+)*$} }
    end

    def self.check_project_scope(scope)
      case scope
      when nil, :absent, 'absent'
        return true
      when [nil], [:absent], ['absent']
        return true
      when String
        return check_project_name(scope)
      when Array
        return scope.all? { |s| check_project_scope(s) }
      else
        return false unless scope.is_a?(Hash)
      end

      s = scope.map { |k, v| [k.to_s, v] }.to_h
      actions = s['actions']
      name    = s['name']
      type    = s['type']

      return false unless name

      if type
        return false unless type.to_s == 'repository'
      end

      if actions
        a = [actions].flatten.map { |x| x.to_s }

        return false unless a.all? { |x| ['*', 'delete', 'pull', 'push'].include?(x) }
      end

      check_project_name(name)
    end

    def self.sort_scope(scope)
      [scope].flatten.compact.sort_by { |a| a['name'] }
    end
  end
end
