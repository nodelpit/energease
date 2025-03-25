# Configure les services à utiliser selon l'environnement
# Ce bloc sera exécuté APRÈS le chargement des classes de l'application
Rails.application.config.to_prepare do
  if Rails.env.production?
    # En production, utiliser les vrais services
    Object.const_set(:EnedisApiService, Enedis::ApiService)
    Object.const_set(:EnedisOauthService, Enedis::OauthService)
  else
    # En développement/test, utiliser les mocks
    Object.const_set(:EnedisApiService, Enedis::MockApiService)
    Object.const_set(:EnedisOauthService, Enedis::MockOauthService)
  end
end
