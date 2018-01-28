class MessengerSettingsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  def update
    setting = MessengerSetting.find_or_create @project.id
    setting.assign_attributes(params[:setting])
    if setting.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = 'Updating failed.' + e.message
    end
    redirect_to settings_project_path(@project, tab: 'messenger')
  end
end
