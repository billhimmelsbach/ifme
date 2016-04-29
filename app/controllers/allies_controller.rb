class AlliesController < ApplicationController
  before_filter :if_not_signed_in

  # GET /allies
  # GET /allies.json
  def index
    @page_search = true
    @accepted_allies = current_user.allies_by_status(:accepted)
    @incoming_ally_requests = current_user.allies_by_status(:pending_from_user)
    @outgoing_ally_requests = current_user.allies_by_status(:pending_from_ally)
    @page_title = "Allies"
  end

  def add
    allyship = Allyship.find_by(user_id: current_user.id, ally_id: params[:ally_id])

    if allyship
      allyship.update(status: User::ALLY_STATUS[:accepted])

      # Notify the user who made the request
      pusher_type = 'accepted_ally_request'
    else
      Allyship.create(
        user_id: current_user.id,
        ally_id: params[:ally_id],
        status: User::ALLY_STATUS[:pending_from_ally]
      )

      # Notify the user the request has been made to
      pusher_type = 'new_ally_request'
    end

    user = User.where(id: current_user.id).first.name
    uniqueid = pusher_type.to_s + '_' + current_user.id.to_s

    data = {
      user: user,
      userid: current_user.id,
      type: pusher_type,
      uniqueid: uniqueid
      }

    Pusher['private-' + params[:ally_id]].trigger('new_notification', data)
    Notification.create(userid: params[:ally_id], uniqueid: uniqueid, data: data)
    
    respond_to do |format|
      format.html { redirect_to params[:refresh] }
      format.json { head :no_content }
    end
  end

  def remove
    # Remove original ally request notifications
    # Case 1: user terminating allyship did not initiate allyship
    uniqueid = 'new_ally_request_' + params[:ally_id].to_s
    Notification.find_by(user_id: current_user.id, uniqueid: uniqueid).destroy
    uniqueid = 'accepted_ally_request_' + current_user.id.to_s
    Notification.find_by(user_id: params[:ally_id], uniqueid: uniqueid).destroy

    # Case 2: user terminating allyship did initiate allyship
    uniqueid = 'new_ally_request_' + current_user.id.to_s
    Notification.find_by(user_id: params[:ally_id], uniqueid: uniqueid).destroy
    uniqueid = 'accepted_ally_request_' + params[:ally_id].to_s
    Notification.find_by(user_id: current_user.id, uniqueid: uniqueid).destroy

    # Destroy allyship
    Allyship.find_by(user_id: current_user.id, ally_id: params[:ally_id]).destroy

    respond_to do |format|
      format.html { redirect_to params[:refresh] }
      format.json { head :no_content }
    end
  end

  private

  def if_not_signed_in
    if !user_signed_in?
      respond_to do |format|
        format.html { redirect_to new_user_session_path }
        format.json { head :no_content }
      end
    end
  end
end
