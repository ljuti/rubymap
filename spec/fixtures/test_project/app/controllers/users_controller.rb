# frozen_string_literal: true

# Controller for managing users
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  before_action :authorize_admin!, only: [:destroy]

  # GET /users
  def index
    @users = User.active.page(params[:page])
    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  # GET /users/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @user }
    end
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
    authorize_edit!
  end

  # POST /users
  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to @user, notice: "User was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /users/1
  def update
    authorize_edit!

    if @user.update(user_params)
      redirect_to @user, notice: "User was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy
    redirect_to users_url, notice: "User was successfully destroyed."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :age, :role)
  end

  def authorize_edit!
    unless current_user.admin? || current_user == @user
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def authorize_admin!
    redirect_to root_path, alert: "Not authorized" unless current_user.admin?
  end
end
