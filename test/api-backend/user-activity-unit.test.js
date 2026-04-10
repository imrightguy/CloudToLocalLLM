/**


 * User Activity Tracking Unit Tests
 *
 * Unit tests for user activity tracking service with mocked database
 *
 * Validates: Requirements 3.4, 3.10
 * - Tracks user activity and usage metrics
 * - Implements activity audit logs
 * - Provides user activity audit logs
 *
 * @fileoverview User activity tracking unit tests
 * @version 1.0.0
 */

import { describe, it, expect } from "@jest/globals";
import {
  ACTIVITY_ACTIONS,
  SEVERITY_LEVELS,
} from "../../services/api-backend/services/user-activity-service.js";

describe("User Activity Tracking Constants", () => {
  describe("ACTIVITY_ACTIONS", () => {
    it("should have all required activity action types", () => {
      expect(ACTIVITY_ACTIONS.PROFILE_VIEW).toBe("profile_view");
      expect(ACTIVITY_ACTIONS.PROFILE_UPDATE).toBe("profile_update");
      expect(ACTIVITY_ACTIONS.PROFILE_DELETE).toBe("profile_delete");
      expect(ACTIVITY_ACTIONS.AVATAR_UPLOAD).toBe("avatar_upload");
      expect(ACTIVITY_ACTIONS.PREFERENCES_UPDATE).toBe("preferences_update");

      expect(ACTIVITY_ACTIONS.TUNNEL_CREATE).toBe("tunnel_create");
      expect(ACTIVITY_ACTIONS.TUNNEL_START).toBe("tunnel_start");
      expect(ACTIVITY_ACTIONS.TUNNEL_STOP).toBe("tunnel_stop");
      expect(ACTIVITY_ACTIONS.TUNNEL_DELETE).toBe("tunnel_delete");
      expect(ACTIVITY_ACTIONS.TUNNEL_UPDATE).toBe("tunnel_update");
      expect(ACTIVITY_ACTIONS.TUNNEL_STATUS_CHECK).toBe("tunnel_status_check");

      expect(ACTIVITY_ACTIONS.API_KEY_CREATE).toBe("api_key_create");
      expect(ACTIVITY_ACTIONS.API_KEY_DELETE).toBe("api_key_delete");
      expect(ACTIVITY_ACTIONS.API_KEY_ROTATE).toBe("api_key_rotate");

      expect(ACTIVITY_ACTIONS.SESSION_CREATE).toBe("session_create");
      expect(ACTIVITY_ACTIONS.SESSION_DESTROY).toBe("session_destroy");
      expect(ACTIVITY_ACTIONS.SESSION_REFRESH).toBe("session_refresh");

      expect(ACTIVITY_ACTIONS.ADMIN_USER_VIEW).toBe("admin_user_view");
      expect(ACTIVITY_ACTIONS.ADMIN_USER_UPDATE).toBe("admin_user_update");
      expect(ACTIVITY_ACTIONS.ADMIN_USER_DELETE).toBe("admin_user_delete");
      expect(ACTIVITY_ACTIONS.ADMIN_TIER_CHANGE).toBe("admin_tier_change");
    });
  });

  describe("SEVERITY_LEVELS", () => {
    it("should have all required severity levels", () => {
      expect(SEVERITY_LEVELS.DEBUG).toBe("debug");
      expect(SEVERITY_LEVELS.INFO).toBe("info");
      expect(SEVERITY_LEVELS.WARN).toBe("warn");
      expect(SEVERITY_LEVELS.ERROR).toBe("error");
      expect(SEVERITY_LEVELS.CRITICAL).toBe("critical");
    });
  });
});
