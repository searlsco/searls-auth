require "uri"

module Searls
  module Auth
    class GeneratesFullUrl
      def initialize(request, drop_subdomain:, path_supplied:)
        @request = request
        @drop_subdomain = drop_subdomain
        @path_supplied = path_supplied
      end

      def generate(path:, subdomain:)
        sanitized_path = presence(path)
        host = resolve_host(subdomain)

        return nil if host == request.host && sanitized_path.nil? && !path_supplied?

        path_for_url = sanitized_path
        path_for_url ||= "/" if host != request.host
        return nil if path_for_url.nil?

        if host == request.host
          path_for_url
        else
          absolute_url(host, path_for_url)
        end
      end

      private

      attr_reader :request

      def path_supplied?
        @path_supplied
      end

      def resolve_host(subdomain)
        current_subdomain = presence(request.subdomain)

        if drop_subdomain? && current_subdomain
          root_host || request.host
        elsif present?(subdomain) && (current_subdomain.nil? || subdomain != current_subdomain)
          target_subdomain_host(subdomain)
        else
          request.host
        end
      end

      def target_subdomain_host(subdomain)
        base = root_host
        if base
          [subdomain, base].join(".")
        else
          [subdomain, request.host].join(".")
        end
      end

      def root_host
        presence(request.domain) || base_uri.host_without_subdomain
      end

      def absolute_url(host, path)
        components = split_path(path)
        uri = base_uri.to_uri
        uri.host = host
        uri.path = components[:path]
        uri.query = components[:query]
        uri.fragment = components[:fragment]
        uri.to_s
      end

      def split_path(path)
        path_and_fragment = path.split("#", 2)
        path_and_query = path_and_fragment[0]
        {
          path: path_and_query.split("?", 2)[0],
          query: path_and_query.include?("?") ? path_and_query.split("?", 2)[1] : nil,
          fragment: path_and_fragment[1]
        }
      end

      def base_uri
        @base_uri ||= BaseUri.new(request)
      end

      class BaseUri
        attr_reader :request

        def initialize(request)
          @request = request
        end

        def to_uri
          URI.parse(request.base_url)
        end

        def host_without_subdomain
          domain = request.domain
          return domain if domain && !(domain.respond_to?(:empty?) ? domain.empty? : false)

          host = to_uri.host
          subdomain = request.subdomain
          return host if subdomain.nil? || (subdomain.respond_to?(:empty?) && subdomain.empty?)

          subdomain_prefix = "#{subdomain}."
          host.start_with?(subdomain_prefix) ? host.delete_prefix(subdomain_prefix) : host
        end
      end

      def present?(value)
        !blank?(value)
      end

      def blank?(value)
        value.respond_to?(:empty?) ? value.empty? : !value
      end

      def presence(value)
        blank?(value) ? nil : value
      end

      def drop_subdomain?
        @drop_subdomain
      end
    end
  end
end
