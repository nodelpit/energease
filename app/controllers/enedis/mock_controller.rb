class Enedis::MockController < ApplicationController
  def oauth_callback
    redirect_to callback_oauth_path(code: "mock_code_#{SecureRandom.hex(8)}", state: params[:state])
  end
end
