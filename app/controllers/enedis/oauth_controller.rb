class Enedis::OauthController < ApplicationController
  before_action :authenticate_user!

  def authorize
    # Génère un état unique pour la sécurité
    state = SecureRandom.hex(16)
    session[:oauth_state] = state

    # Utilise automatiquement le bon service selon l'environnement
    oauth_service = EnedisOauthService.new(current_user)
    redirect_to oauth_service.authorization_url(state: state, callback_url: callback_url), allow_other_host: true
  end

  def callback
    # Vérifie l'état pour la sécurité
    if params[:state] != session[:oauth_state]
      flash[:alert] = "Erreur de sécurité lors de l'autorisation."
      return redirect_to enedis_consumptions_path
    end

    if params[:code].present?
      # Échange le code contre un token d'accès avec le service mock
      begin
        # Utilise automatiquement le bon service selon l'environnement
        oauth_service = EnedisOauthService.new(current_user)
        oauth_service.exchange_authorization_code(params[:code], callback_url)

        flash[:notice] = Rails.env.production? ? "Autorisation Enedis réussie! Vous pouvez maintenant accéder à vos données de consommation." :
        "Autorisation Enedis simulée! Vous pouvez maintenant accéder à vos données de consommation."
      rescue => e
        flash[:alert] = "Erreur lors de l'échange de code d'autorisation : #{e.message}"
      end
    else
      flash[:alert] = "Erreur lors de l'autorisation : #{params[:error]}"
    end

    redirect_to enedis_consumptions_path
  end

  private

  def callback_url
    callback_oauth_url
  end
end
