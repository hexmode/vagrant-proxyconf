require_relative '../logger'
require_relative '../userinfo_uri'

module VagrantPlugins
  module ProxyConf
    class Action
      # Action for configuring Chef provisioners
      class ConfigureChefProxy
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]
          config  = config(machine)

          if chef_provisioners(machine).empty?
            logger.info I18n.t("vagrant_proxyconf.chef_proxy.no_provisioners")
          elsif !config.enabled?
            logger.info I18n.t("vagrant_proxyconf.chef_proxy.not_enabled")
          else
            env[:ui].info I18n.t("vagrant_proxyconf.chef_proxy.configuring")
            configure_chef_provisioners(machine, config)
          end

          @app.call env
        end

        private

        # @return [Log4r::Logger]
        def logger
          ProxyConf.logger
        end

        # @return [Config::Proxy] the `config.proxy` configuration
        def config(machine)
          config = machine.config.proxy
          config.finalize! if Gem::Version.new(Vagrant::VERSION) < Gem::Version.new('1.2.5')
          config
        end

        # @return [Array] all Chef provisioners
        def chef_provisioners(machine)
          machine.config.vm.provisioners.select { |prov| [:chef_solo, :chef_client].include?(prov.name) }
        end

        # Configures all Chef provisioner based on the default config
        #
        # @param config [Config::Proxy] the default configuration
        def configure_chef_provisioners(machine, config)
          chef_provisioners(machine).each { |prov| configure_chef(prov.config, config) }
        end

        # Configures proxies for a Chef provisioner if they are not set
        #
        # @param chef [VagrantPlugins::Chef::Config::Base] the Chef provisioner configuration
        # @param config [Config::Proxy] the default configuration
        def configure_chef(chef, config)
          configure_chef_proxy(chef, 'http', config.http)
          configure_chef_proxy(chef, 'https', config.https)
          chef.no_proxy ||= config.no_proxy if config.no_proxy
        end

        # @param chef [VagrantPlugins::Chef::Config::Base] the Chef provisioner configuration
        # @param scheme [String] the http protocol (http or https)
        # @param uri [String] the URI with optional userinfo
        def configure_chef_proxy(chef, scheme, uri)
          if uri && !chef.public_send("#{scheme}_proxy")
            u = UserinfoURI.new(uri)
            chef.public_send("#{scheme}_proxy_user=", u.user)
            chef.public_send("#{scheme}_proxy_pass=", u.pass)
            chef.public_send("#{scheme}_proxy=", u.uri)
          end
        end
      end
    end
  end
end
