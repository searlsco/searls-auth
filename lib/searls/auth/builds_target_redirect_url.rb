require "uri"
require "rack/utils"

module Searls
  module Auth
    class BuildsTargetRedirectUrl
      def build(request, params, user: nil)
        path = normalize_path(params[:redirect_path])
        host = resolve_host(request, params[:redirect_subdomain], params[:redirect_host])

        if host == request.host && path.present?
          path
        elsif host != request.host
          url = absolute_url(request, host, path)
          append_cross_domain_sso_token(url, request, user)
        end
      end

      private

      def normalize_path(raw)
        if !raw.nil? && !(v = raw.to_s.strip).empty?
          v = v.sub(%r{\Ahttps?://[^/?#]+}i, "")
          "/#{v}".sub(%r{\A/+/}, "/")
        end
      end

      def resolve_host(request, subdomain, redirect_host)
        if (host = allowed_redirect_host(request, redirect_host))
          host
        else
          host_from_subdomain(request, subdomain)
        end
      end

      def allowed_redirect_host(request, raw)
        host = normalize_redirect_host(raw)
        return if host.blank?
        return unless Searls::Auth.config.redirect_host_allowed_predicate.call(host, request)

        host
      end

      def normalize_redirect_host(raw)
        v = raw.to_s.strip.downcase
        return if v.blank?

        if /\A[a-z0-9.-]+\z/.match?(v)
          v
        end
      end

      def host_from_subdomain(request, subdomain)
        s = normalize_subdomain(subdomain)
        cur = request.subdomain.presence
        return request.host if s.nil? || s == cur || (s == "" && cur.nil?)
        return root_host(request) || request.host if s == "" && cur
        base = root_host(request) || request.host
        "#{s}.#{base}"
      end

      def normalize_subdomain(raw)
        return "" if raw.is_a?(String) && raw.strip.empty?
        if (v = raw.to_s.downcase).present?
          v if /\A[a-z0-9-]+\z/.match?(v)
        end
      end

      def root_host(request)
        request.domain.presence || begin
          host = URI.parse(request.base_url).host
          sub = request.subdomain.to_s
          if sub.empty?
            host
          else
            pref = "#{sub}."
            host.start_with?(pref) ? host.delete_prefix(pref) : host
          end
        end
      end

      def absolute_url(request, host, path)
        uri = URI.parse(request.base_url)
        uri.host = host
        if path && !path.empty?
          m = path.match(/\A([^?#]*)(?:\?([^#]*))?(?:#(.*))?\z/)
          uri.path = m[1]
          uri.query = m[2]
          uri.fragment = m[3]
        else
          uri.path = ""
          uri.query = nil
          uri.fragment = nil
        end
        uri.to_s
      end

      def append_cross_domain_sso_token(url, request, user)
        return url if user.blank?

        generator = Searls::Auth.config.cross_domain_sso_token_generator
        return url if generator.nil?

        uri = URI.parse(url)
        return url unless Searls::Auth.config.cross_cookie_domain_predicate.call(request, uri.host)

        token = generator.call(user, request)
        return url if token.blank?

        param_name = Searls::Auth.config.cross_domain_sso_token_param_name.to_s
        return url if param_name.blank?

        query = Rack::Utils.parse_nested_query(uri.query)
        query[param_name] = token
        uri.query = Rack::Utils.build_nested_query(query)
        uri.to_s
      end
    end
  end
end
