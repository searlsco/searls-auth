require "uri"

module Searls
  module Auth
    class BuildsTargetRedirectUrl
      def build(request, params)
        path = normalize_path(params[:redirect_path])
        host = resolve_host(request, params[:redirect_subdomain])

        if host == request.host && path.present?
          path
        elsif host != request.host
          absolute_url(request, host, path)
        end
      end

      private

      def normalize_path(raw)
        if !raw.nil? && !(v = raw.to_s.strip).empty?
          v = v.sub(%r{\Ahttps?://[^/?#]+}i, "")
          "/#{v}".sub(%r{\A/+/}, "/")
        end
      end

      def resolve_host(request, subdomain)
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
    end
  end
end
