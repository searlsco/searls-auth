require "uri"
require "rack/utils"

module Searls
  module Auth
    class BuildsTargetRedirectUrl
      def build(request, params, user: nil)
        path = normalize_path(params[:redirect_path])
        host = normalize_redirect_host(params[:redirect_host])

        if (host.blank? || host == request.host) && path.present?
          path
        elsif host.present? && host != request.host
          url = absolute_url(request, host, path)
          append_cross_domain_sso_token(url, request, user, host) || path
        end
      end

      private

      def normalize_path(raw)
        if !raw.nil? && !(v = raw.to_s.strip).empty?
          v = v.sub(%r{\Ahttps?://[^/?#]+}i, "")
          "/#{v}".sub(%r{\A/+/}, "/")
        end
      end

      def normalize_redirect_host(raw)
        v = raw.to_s.strip.downcase
        return if v.blank?

        if /\A[a-z0-9.-]+\z/.match?(v)
          v
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

      def append_cross_domain_sso_token(url, request, user, host)
        return url if cookie_domain_shared?(request, host)
        return if user.blank?

        token = begin
          provider = Searls::Auth.config.token_for_cross_domain_redirect
          provider&.call(user, request, host)
        end
        return if token.blank?

        uri = URI.parse(url)
        query = Rack::Utils.parse_nested_query(uri.query)
        query["sso_token"] = token
        uri.query = Rack::Utils.build_nested_query(query)
        uri.to_s
      end

      def cookie_domain_shared?(request, host)
        domain = request.domain.presence || begin
          parts = request.host.to_s.split(".")
          (parts.length > 2) ? parts.last(2).join(".") : parts.last
        end.to_s
        return false if domain.blank?

        host == domain || host.end_with?(".#{domain}")
      end
    end
  end
end
