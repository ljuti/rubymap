# frozen_string_literal: true

# Authentication utilities
module Authentication
  class InvalidTokenError < StandardError; end

  # Token generation and validation
  module TokenGenerator
    def self.generate(user)
      payload = {
        user_id: user.id,
        email: user.email,
        exp: 1.hour.from_now.to_i
      }

      JWT.encode(payload, secret_key, "HS256")
    end

    def self.decode(token)
      JWT.decode(token, secret_key, true, algorithm: "HS256").first
    rescue JWT::DecodeError => e
      raise InvalidTokenError, e.message
    end

    def self.secret_key
      Rails.application.secrets.secret_key_base
    end

    private_class_method :secret_key
  end

  # Session management
  class SessionManager
    attr_reader :session, :user

    def initialize(session)
      @session = session
      @user = find_current_user
    end

    def sign_in(user)
      session[:user_id] = user.id
      session[:signed_in_at] = Time.current
      @user = user
    end

    def sign_out
      session.delete(:user_id)
      session.delete(:signed_in_at)
      @user = nil
    end

    def signed_in?
      user.present?
    end

    def session_expired?
      return true unless session[:signed_in_at]

      Time.current > Time.parse(session[:signed_in_at]) + 24.hours
    end

    private

    def find_current_user
      return nil unless session[:user_id]
      return nil if session_expired?

      User.find_by(id: session[:user_id])
    end
  end
end
