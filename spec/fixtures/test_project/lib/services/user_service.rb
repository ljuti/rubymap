# frozen_string_literal: true

module Services
  # Service object for complex user operations
  class UserService
    class UserNotFoundError < StandardError; end

    class InvalidOperationError < StandardError; end

    attr_reader :user, :current_user

    def initialize(user, current_user: nil)
      @user = user
      @current_user = current_user
    end

    # Merge two user accounts
    def merge_with(other_user)
      raise InvalidOperationError, "Cannot merge user with itself" if user == other_user
      raise UserNotFoundError, "Other user not found" unless other_user

      ActiveRecord::Base.transaction do
        # Transfer all posts
        other_user.posts.update_all(user_id: user.id)

        # Transfer all comments
        other_user.comments.update_all(user_id: user.id)

        # Merge profile data
        merge_profile_data(other_user)

        # Deactivate the other account
        other_user.update!(active: false, merged_into_id: user.id)

        # Log the merge
        log_merge(other_user)
      end

      user
    end

    # Export user data for GDPR compliance
    def export_data
      {
        personal_info: extract_personal_info,
        posts: user.posts.map { |p| serialize_post(p) },
        comments: user.comments.map { |c| serialize_comment(c) },
        activity_log: extract_activity_log,
        exported_at: Time.current
      }
    end

    # Anonymize user data
    def anonymize!
      user.update!(
        email: "deleted_#{user.id}@example.com",
        name: "Deleted User",
        first_name: nil,
        last_name: nil,
        phone: nil,
        address: nil,
        anonymized_at: Time.current
      )
    end

    class << self
      def bulk_invite(emails, inviter:)
        emails.map do |email|
          user = User.create!(
            email: email,
            name: email.split("@").first,
            invited_by: inviter,
            invitation_sent_at: Time.current
          )

          UserMailer.invitation(user, inviter).deliver_later
          user
        end
      end

      def find_duplicates
        User.group(:email).having("count(*) > 1").pluck(:email)
      end
    end

    private

    def merge_profile_data(other_user)
      # Implement profile merging logic
      user.update!(
        posts_count: user.posts_count + other_user.posts_count,
        comments_count: user.comments_count + other_user.comments_count
      )
    end

    def log_merge(other_user)
      Rails.logger.info "Merged user #{other_user.id} into #{user.id}"
    end

    def extract_personal_info
      user.attributes.slice("email", "name", "first_name", "last_name", "created_at")
    end

    def serialize_post(post)
      post.attributes.slice("title", "content", "created_at")
    end

    def serialize_comment(comment)
      comment.attributes.slice("content", "created_at")
    end

    def extract_activity_log
      # Simplified activity log extraction
      []
    end
  end
end
