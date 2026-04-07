/**


 * User Profile API Tests
 *
 * Tests for user profile endpoints:
 * - GET /api/users/profile - Retrieve user profile
 * - PUT /api/users/profile - Update user profile
 * - GET /api/users/preferences - Get user preferences
 * - PUT /api/users/preferences - Update user preferences
 * - PUT /api/users/avatar - Update user avatar
 *
 * Validates: Requirements 3.1, 3.2, 3.8, 3.9
 * - Provides endpoints for user profile retrieval and updates
 * - Supports user preference storage (theme, language, notifications)
 * - Supports user avatar/profile picture uploads
 * - Implements user notification preferences
 *
 * @fileoverview User profile endpoint tests
 * @version 1.0.0
 */

import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
} from "@jest/globals";
import { UserProfileService } from "../../services/api-backend/services/user-profile-service.js";

describe("UserProfileService", () => {
  let userProfileService;
  let mockPool;

  beforeEach(() => {
    // Create mock pool
    mockPool = {
      query: jest.fn(),
      connect: jest.fn(),
    };

    userProfileService = new UserProfileService();
    userProfileService.pool = mockPool;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("getUserProfile", () => {
    it("should retrieve user profile successfully", async () => {
      const userId = "jwt|123456";
      const mockUserData = {
        id: "user-uuid-1",
        jwt_id: userId,
        email: "user@example.com",
        name: "John Doe",
        nickname: "johndoe",
        picture: "https://example.com/avatar.jpg",
        email_verified: true,
        locale: "en",
        created_at: new Date("2024-01-01"),
        updated_at: new Date("2024-01-15"),
        last_login: new Date("2024-01-15"),
        login_count: 5,
        metadata: {},
        preferences: {
          theme: "dark",
          language: "en",
          notifications: true,
        },
      };

      mockPool.query.mockResolvedValueOnce({
        rows: [mockUserData],
      });

      const profile = await userProfileService.getUserProfile(userId);

      expect(profile).toEqual({
        id: "user-uuid-1",
        jwtId: userId,
        email: "user@example.com",
        profile: {
          firstName: "John",
          lastName: "Doe",
          nickname: "johndoe",
          avatar: "https://example.com/avatar.jpg",
          preferences: {
            theme: "dark",
            language: "en",
            notifications: true,
          },
        },
        emailVerified: true,
        locale: "en",
        createdAt: mockUserData.created_at,
        updatedAt: mockUserData.updated_at,
        lastLogin: mockUserData.last_login,
        loginCount: 5,
        metadata: {},
      });

      expect(mockPool.query).toHaveBeenCalledTimes(1);
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(userProfileService.getUserProfile(userId)).rejects.toThrow(
        "User not found",
      );
    });

    it("should throw error for invalid user ID", async () => {
      await expect(userProfileService.getUserProfile(null)).rejects.toThrow(
        "Invalid user ID",
      );

      await expect(userProfileService.getUserProfile("")).rejects.toThrow(
        "Invalid user ID",
      );
    });

    it("should handle default preferences when not set", async () => {
      const userId = "jwt|123456";
      const mockUserData = {
        id: "user-uuid-1",
        jwt_id: userId,
        email: "user@example.com",
        name: "John Doe",
        nickname: null,
        picture: null,
        email_verified: false,
        locale: null,
        created_at: new Date("2024-01-01"),
        updated_at: new Date("2024-01-01"),
        last_login: null,
        login_count: 0,
        metadata: {},
        preferences: null,
      };

      mockPool.query.mockResolvedValueOnce({
        rows: [mockUserData],
      });

      const profile = await userProfileService.getUserProfile(userId);

      expect(profile.profile.preferences).toEqual({
        theme: "light",
        language: "en",
        notifications: true,
      });
    });
  });

  describe("updateUserProfile", () => {
    it("should update user profile successfully", async () => {
      const userId = "jwt|123456";
      const profileData = {
        profile: {
          firstName: "Jane",
          lastName: "Smith",
          nickname: "janesmith",
          avatar: "https://example.com/new-avatar.jpg",
          preferences: {
            theme: "dark",
            language: "es",
            notifications: false,
          },
        },
      };

      const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
      };

      mockPool.connect.mockResolvedValueOnce(mockClient);
      mockClient.query.mockResolvedValue({ rows: [] });

      // Mock the getUserProfile call after update
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: "user-uuid-1",
            jwt_id: userId,
            email: "user@example.com",
            name: "Jane Smith",
            nickname: "janesmith",
            picture: "https://example.com/new-avatar.jpg",
            email_verified: true,
            locale: "es",
            created_at: new Date("2024-01-01"),
            updated_at: new Date("2024-01-15"),
            last_login: new Date("2024-01-15"),
            login_count: 5,
            metadata: {},
            preferences: {
              theme: "dark",
              language: "es",
              notifications: false,
            },
          },
        ],
      });

      const updatedProfile = await userProfileService.updateUserProfile(
        userId,
        profileData,
      );

      expect(updatedProfile.profile.firstName).toBe("Jane");
      expect(updatedProfile.profile.lastName).toBe("Smith");
      expect(updatedProfile.profile.preferences.theme).toBe("dark");
      expect(mockClient.query).toHaveBeenCalledWith("BEGIN");
      expect(mockClient.query).toHaveBeenCalledWith("COMMIT");
    });

    it("should validate profile data before updating", async () => {
      const userId = "jwt|123456";

      // Invalid first name (too long)
      const invalidData = {
        profile: {
          firstName: "a".repeat(101),
        },
      };

      await expect(
        userProfileService.updateUserProfile(userId, invalidData),
      ).rejects.toThrow("Name must be between 0 and 100 characters");
    });

    it("should validate avatar URL format", async () => {
      const userId = "jwt|123456";

      const invalidData = {
        profile: {
          avatar: "not-a-valid-url",
        },
      };

      await expect(
        userProfileService.updateUserProfile(userId, invalidData),
      ).rejects.toThrow("Avatar: Invalid URL format");
    });

    it("should rollback transaction on error", async () => {
      const userId = "jwt|123456";
      const profileData = {
        profile: {
          firstName: "Jane",
        },
      };

      const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
      };

      mockPool.connect.mockResolvedValueOnce(mockClient);
      mockClient.query.mockRejectedValueOnce(new Error("Database error"));

      await expect(
        userProfileService.updateUserProfile(userId, profileData),
      ).rejects.toThrow("Database error");

      expect(mockClient.query).toHaveBeenCalledWith("ROLLBACK");
    });
  });

  describe("updateUserPreferences", () => {
    it("should update user preferences successfully", async () => {
      const userId = "jwt|123456";
      const preferences = {
        theme: "dark",
        language: "fr",
        notifications: false,
      };

      mockPool.query.mockResolvedValueOnce({
        rows: [{ preferences }],
      });

      const updatedPreferences = await userProfileService.updateUserPreferences(
        userId,
        preferences,
      );

      expect(updatedPreferences).toEqual(preferences);
      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining("INSERT INTO user_preferences"),
        [JSON.stringify(preferences), userId],
      );
    });

    it("should validate theme preference", async () => {
      const userId = "jwt|123456";
      const invalidPreferences = {
        theme: "invalid-theme",
      };

      await expect(
        userProfileService.updateUserPreferences(userId, invalidPreferences),
      ).rejects.toThrow("Theme must be one of: light, dark");
    });

    it("should validate notifications preference type", async () => {
      const userId = "jwt|123456";
      const invalidPreferences = {
        notifications: "yes", // Should be boolean
      };

      await expect(
        userProfileService.updateUserPreferences(userId, invalidPreferences),
      ).rejects.toThrow("Notifications must be a boolean");
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";
      const preferences = { theme: "dark" };

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(
        userProfileService.updateUserPreferences(userId, preferences),
      ).rejects.toThrow("User not found");
    });
  });

  describe("getUserPreferences", () => {
    it("should retrieve user preferences successfully", async () => {
      const userId = "jwt|123456";
      const preferences = {
        theme: "dark",
        language: "en",
        notifications: true,
      };

      mockPool.query.mockResolvedValueOnce({
        rows: [{ preferences }],
      });

      const result = await userProfileService.getUserPreferences(userId);

      expect(result).toEqual(preferences);
    });

    it("should return default preferences when not set", async () => {
      const userId = "jwt|123456";

      mockPool.query.mockResolvedValueOnce({
        rows: [{ preferences: null }],
      });

      const result = await userProfileService.getUserPreferences(userId);

      expect(result).toEqual({
        theme: "light",
        language: "en",
        notifications: true,
      });
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(
        userProfileService.getUserPreferences(userId),
      ).rejects.toThrow("User not found");
    });
  });

  describe("updateUserAvatar", () => {
    it("should update user avatar successfully", async () => {
      const userId = "jwt|123456";
      const avatarUrl = "https://example.com/new-avatar.jpg";

      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: "user-uuid-1" }],
      });

      // Mock the getUserProfile call after update
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: "user-uuid-1",
            jwt_id: userId,
            email: "user@example.com",
            name: "John Doe",
            nickname: "johndoe",
            picture: avatarUrl,
            email_verified: true,
            locale: "en",
            created_at: new Date("2024-01-01"),
            updated_at: new Date("2024-01-15"),
            last_login: new Date("2024-01-15"),
            login_count: 5,
            metadata: {},
            preferences: {
              theme: "light",
              language: "en",
              notifications: true,
            },
          },
        ],
      });

      const updatedProfile = await userProfileService.updateUserAvatar(
        userId,
        avatarUrl,
      );

      expect(updatedProfile.profile.avatar).toBe(avatarUrl);
    });

    it("should validate avatar URL format", async () => {
      const userId = "jwt|123456";
      const invalidUrl = "not-a-valid-url";

      await expect(
        userProfileService.updateUserAvatar(userId, invalidUrl),
      ).rejects.toThrow("Invalid URL format");
    });

    it("should throw error for invalid user ID", async () => {
      await expect(
        userProfileService.updateUserAvatar(
          null,
          "https://example.com/avatar.jpg",
        ),
      ).rejects.toThrow("Invalid user ID");
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";
      const avatarUrl = "https://example.com/avatar.jpg";

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(
        userProfileService.updateUserAvatar(userId, avatarUrl),
      ).rejects.toThrow("User not found");
    });
  });

  describe("Preference Validation", () => {
    it("should validate all preference fields", async () => {
      const userId = "jwt|123456";

      // Valid preferences
      const validPreferences = {
        theme: "light",
        language: "en",
        notifications: true,
      };

      mockPool.query.mockResolvedValueOnce({
        rows: [{ preferences: validPreferences }],
      });

      const result = await userProfileService.updateUserPreferences(
        userId,
        validPreferences,
      );

      expect(result).toEqual(validPreferences);
    });

    it("should allow partial preference updates", async () => {
      const userId = "jwt|123456";

      // Partial preferences
      const partialPreferences = {
        theme: "dark",
      };

      mockPool.query.mockResolvedValueOnce({
        rows: [{ preferences: partialPreferences }],
      });

      const result = await userProfileService.updateUserPreferences(
        userId,
        partialPreferences,
      );

      expect(result).toEqual(partialPreferences);
    });

    it("should validate language length", async () => {
      const userId = "jwt|123456";

      const invalidPreferences = {
        language: "a".repeat(11), // Too long
      };

      await expect(
        userProfileService.updateUserPreferences(userId, invalidPreferences),
      ).rejects.toThrow("Language must be between 1 and 10 characters");
    });
  });

  describe("Profile Data Validation", () => {
    it("should validate name lengths", async () => {
      const userId = "jwt|123456";

      const invalidData = {
        profile: {
          lastName: "a".repeat(101), // Too long
        },
      };

      await expect(
        userProfileService.updateUserProfile(userId, invalidData),
      ).rejects.toThrow("Last name: Name must be between 0 and 100 characters");
    });

    it("should validate nickname length", async () => {
      const userId = "jwt|123456";

      const invalidData = {
        profile: {
          nickname: "a".repeat(101), // Too long
        },
      };

      await expect(
        userProfileService.updateUserProfile(userId, invalidData),
      ).rejects.toThrow("Nickname must be between 0 and 100 characters");
    });

    it("should allow empty avatar URL", async () => {
      const userId = "jwt|123456";

      const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
      };

      mockPool.connect.mockResolvedValueOnce(mockClient);
      mockClient.query.mockResolvedValue({ rows: [] });

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: "user-uuid-1",
            jwt_id: userId,
            email: "user@example.com",
            name: "John Doe",
            nickname: "johndoe",
            picture: null,
            email_verified: true,
            locale: "en",
            created_at: new Date("2024-01-01"),
            updated_at: new Date("2024-01-15"),
            last_login: new Date("2024-01-15"),
            login_count: 5,
            metadata: {},
            preferences: {
              theme: "light",
              language: "en",
              notifications: true,
            },
          },
        ],
      });

      const profileData = {
        profile: {
          avatar: "", // Empty string should be allowed
        },
      };

      const result = await userProfileService.updateUserProfile(
        userId,
        profileData,
      );

      expect(result).toBeDefined();
    });
  });
});
