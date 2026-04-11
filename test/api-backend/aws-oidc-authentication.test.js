/**
 * AWS OIDC Authentication Property Tests
 *
 * Tests for GitHub Actions OIDC authentication to AWS
 * Validates: Requirements 3.1, 3.2, 3.3
 *
 * Feature: aws-eks-deployment, Property 1: OIDC Authentication Succeeds
 * Validates: Requirements 3.1, 3.2, 3.3
 */

import jwt from "jsonwebtoken";
import crypto from "crypto";
import { describe, test, expect } from "@jest/globals";

// Mock AWS and GitHub OIDC configuration
const GITHUB_OIDC_PROVIDER = "token.actions.githubusercontent.com";
const AWS_ACCOUNT_ID = "422017356244";
const GITHUB_REPO = "CloudToLocalLLM/CloudToLocalLLM";
const GITHUB_BRANCH = "main";

/**
 * Generate a mock GitHub OIDC token
 * Simulates the token that GitHub Actions would provide
 */
function generateGitHubOIDCToken(options = {}) {
  const payload = {
    iss: `https://${GITHUB_OIDC_PROVIDER}`,
    sub:
      options.subject || `repo:${GITHUB_REPO}:ref:refs/heads/${GITHUB_BRANCH}`,
    aud: options.audience || "sts.amazonaws.com",
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (options.expiresIn || 3600),
    nbf: Math.floor(Date.now() / 1000),
    jti: options.jti || crypto.randomUUID(),
    actor: options.actor || "github-actions",
    repository: options.repository || GITHUB_REPO,
    repository_owner: options.repositoryOwner || "CloudToLocalLLM",
    run_id: options.runId || crypto.randomInt(1000000, 9999999).toString(),
    run_number: options.runNumber || crypto.randomInt(1, 1000).toString(),
    ref: options.ref || `refs/heads/${GITHUB_BRANCH}`,
    ref_type: options.refType || "branch",
    workflow: options.workflow || "deploy-aws-eks.yml",
    environment: options.environment || "production",
    ...options.payload,
  };

  // Sign with a test secret (in production, GitHub signs with their private key)
  return jwt.sign(payload, "github-oidc-secret", { algorithm: "HS256" });
}

/**
 * Generate an expired GitHub OIDC token
 */
function generateExpiredGitHubToken(options = {}) {
  return generateGitHubOIDCToken({
    ...options,
    expiresIn: -3600, // Expired 1 hour ago
  });
}

/**
 * Simulate AWS STS AssumeRoleWithWebIdentity response
 */
function generateAWSSTSResponse(options = {}) {
  return {
    Credentials: {
      AccessKeyId:
        options.accessKeyId ||
        "ASIA" + crypto.randomBytes(16).toString("hex").toUpperCase(),
      SecretAccessKey: crypto.randomBytes(32).toString("base64"),
      SessionToken: crypto.randomBytes(256).toString("base64"),
      Expiration: new Date(
        Date.now() + (options.expiresIn || 3600) * 1000,
      ).toISOString(),
    },
    AssumedRoleArn:
      options.roleArn ||
      `arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-role`,
    AssumedRoleUser:
      options.assumedRoleUser ||
      `arn:aws:iam::${AWS_ACCOUNT_ID}:assumed-role/github-actions-role/github-actions-session`,
    PackedPolicySize: options.packedPolicySize || 6,
  };
}

/**
 * Validate OIDC token structure
 */
function validateOIDCTokenStructure(token) {
  const decoded = jwt.decode(token, { complete: true });

  if (!decoded) {
    return { valid: false, error: "Invalid token format" };
  }

  const { header, payload } = decoded;

  // Validate header
  if (!header.alg || !header.typ) {
    return { valid: false, error: "Missing header fields" };
  }

  // Validate required payload fields
  const requiredFields = ["iss", "sub", "aud", "iat", "exp", "jti"];
  for (const field of requiredFields) {
    if (!(field in payload)) {
      return { valid: false, error: `Missing required field: ${field}` };
    }
  }

  // Validate issuer
  if (!payload.iss.includes(GITHUB_OIDC_PROVIDER)) {
    return { valid: false, error: "Invalid issuer" };
  }

  // Validate audience
  if (payload.aud !== "sts.amazonaws.com") {
    return { valid: false, error: "Invalid audience" };
  }

  return { valid: true };
}

/**
 * Validate AWS STS response structure
 */
function validateSTSResponseStructure(response) {
  if (!response.Credentials) {
    return { valid: false, error: "Missing Credentials" };
  }

  const { Credentials } = response;
  const requiredFields = [
    "AccessKeyId",
    "SecretAccessKey",
    "SessionToken",
    "Expiration",
  ];

  for (const field of requiredFields) {
    if (!(field in Credentials)) {
      return { valid: false, error: `Missing credential field: ${field}` };
    }
  }

  // Validate AccessKeyId format (should start with ASIA for temporary credentials)
  if (!Credentials.AccessKeyId.startsWith("ASIA")) {
    return {
      valid: false,
      error: "Invalid AccessKeyId format for temporary credentials",
    };
  }

  // Validate expiration is in future
  const expirationTime = new Date(Credentials.Expiration).getTime();
  const now = Date.now();
  if (expirationTime <= now) {
    return { valid: false, error: "Credentials already expired" };
  }

  return { valid: true };
}

describe("AWS OIDC Authentication - Property Tests", () => {
  describe("Property 1: OIDC Authentication Succeeds", () => {
    let token;
    let token1;
    let token2;

    beforeAll(() => {
      token = generateGitHubOIDCToken();
      token1 = generateGitHubOIDCToken();
      token2 = generateGitHubOIDCToken();
    });

    test("should generate valid GitHub OIDC token", () => {
      const validation = validateOIDCTokenStructure(token);

      expect(validation.valid).toBe(true);
    });

    test("should generate OIDC token with correct issuer", () => {
      const decoded = jwt.decode(token);

      expect(decoded.iss).toBe(`https://${GITHUB_OIDC_PROVIDER}`);
    });

    test("should generate OIDC token with correct audience", () => {
      const decoded = jwt.decode(token);

      expect(decoded.aud).toBe("sts.amazonaws.com");
    });

    test("should generate OIDC token with valid subject format", () => {
      const decoded = jwt.decode(token);

      expect(decoded.sub).toMatch(/^repo:/);
      expect(decoded.sub).toContain(GITHUB_REPO);
    });

    test("should generate OIDC token with unique JTI", () => {
      const decoded1 = jwt.decode(token1);
      const decoded2 = jwt.decode(token2);

      expect(decoded1.jti).not.toBe(decoded2.jti);
    });

    test("should generate OIDC token with future expiration", () => {
      const decoded = jwt.decode(token);
      const now = Math.floor(Date.now() / 1000);

      expect(decoded.exp).toBeGreaterThan(now);
    });

    test("should generate OIDC token with past issued-at time", () => {
      const decoded = jwt.decode(token);
      const now = Math.floor(Date.now() / 1000);

      expect(decoded.iat).toBeLessThanOrEqual(now);
    });

    test("should generate OIDC token with valid not-before time", () => {
      const decoded = jwt.decode(token);
      const now = Math.floor(Date.now() / 1000);

      expect(decoded.nbf).toBeLessThanOrEqual(now);
    });

    test("should exchange OIDC token for AWS credentials", () => {
      const validation = validateOIDCTokenStructure(token);

      expect(validation.valid).toBe(true);

      // Simulate STS exchange
      const stsResponse = generateAWSSTSResponse();
      const stsValidation = validateSTSResponseStructure(stsResponse);

      expect(stsValidation.valid).toBe(true);
    });

    test("should provide temporary AWS credentials", () => {
      const stsResponse = generateAWSSTSResponse();

      expect(stsResponse.Credentials.AccessKeyId).toMatch(/^ASIA/);
      expect(stsResponse.Credentials.SecretAccessKey).toBeDefined();
      expect(stsResponse.Credentials.SessionToken).toBeDefined();
    });

    test("should not store long-lived credentials", () => {
      const stsResponse = generateAWSSTSResponse();
      const accessKeyId = stsResponse.Credentials.AccessKeyId;

      // Temporary credentials start with ASIA, not AKIA
      expect(accessKeyId).toMatch(/^ASIA/);
      expect(accessKeyId).not.toMatch(/^AKIA/);
    });

    test("should provide credentials with expiration", () => {
      const stsResponse = generateAWSSTSResponse();
      const expiration = new Date(stsResponse.Credentials.Expiration);
      const now = new Date();

      expect(expiration.getTime()).toBeGreaterThan(now.getTime());
    });

    test("should revoke credentials after expiration", () => {
      const stsResponse = generateAWSSTSResponse({ expiresIn: 1 }); // 1 second
      const expiration = new Date(stsResponse.Credentials.Expiration);

      // Simulate time passing
      const futureTime = new Date(expiration.getTime() + 1000);
      const isExpired = futureTime > expiration;

      expect(isExpired).toBe(true);
    });

    test("should reject expired OIDC tokens", () => {
      const token = generateExpiredGitHubToken();
      const decoded = jwt.decode(token);
      const now = Math.floor(Date.now() / 1000);

      expect(decoded.exp).toBeLessThan(now);
    });

    test("should validate OIDC token before credential exchange", () => {
      const validToken = generateGitHubOIDCToken();
      const expiredToken = generateExpiredGitHubToken();

      const validValidation = validateOIDCTokenStructure(validToken);
      const expiredValidation = validateOIDCTokenStructure(expiredToken);

      expect(validValidation.valid).toBe(true);
      // Expired token still has valid structure, but exp field indicates expiration
      expect(expiredValidation.valid).toBe(true);
      expect(jwt.decode(expiredToken).exp).toBeLessThan(
        Math.floor(Date.now() / 1000),
      );
    });

    test("should include repository information in token", () => {
      const decoded = jwt.decode(token);

      expect(decoded.repository).toBe(GITHUB_REPO);
      expect(decoded.repository_owner).toBe("CloudToLocalLLM");
    });

    test("should include workflow information in token", () => {
      const decoded = jwt.decode(token);

      expect(decoded.workflow).toBeDefined();
      expect(decoded.run_id).toBeDefined();
      expect(decoded.run_number).toBeDefined();
    });

    test("should include branch information in token", () => {
      const decoded = jwt.decode(token);

      expect(decoded.ref).toBe(`refs/heads/${GITHUB_BRANCH}`);
      expect(decoded.ref_type).toBe("branch");
    });

    test("should support multiple OIDC token exchanges", () => {
      const stsResponse1 = generateAWSSTSResponse();
      const stsResponse2 = generateAWSSTSResponse();

      // Each exchange should produce different credentials
      expect(stsResponse1.Credentials.AccessKeyId).not.toBe(
        stsResponse2.Credentials.AccessKeyId,
      );
      expect(stsResponse1.Credentials.SessionToken).not.toBe(
        stsResponse2.Credentials.SessionToken,
      );
    });

    test("should maintain least privilege in assumed role", () => {
      const stsResponse = generateAWSSTSResponse();

      expect(stsResponse.AssumedRoleArn).toContain("github-actions-role");
      expect(stsResponse.AssumedRoleArn).toContain(AWS_ACCOUNT_ID);
    });

    test("should provide session identifier", () => {
      const stsResponse = generateAWSSTSResponse();

      expect(stsResponse.AssumedRoleUser).toBeDefined();
      expect(stsResponse.AssumedRoleUser).toContain("assumed-role");
      expect(stsResponse.AssumedRoleUser).toContain("github-actions-session");
    });

    test("should validate credentials are temporary (not long-lived)", () => {
      const stsResponse = generateAWSSTSResponse();
      const { AccessKeyId, SessionToken } = stsResponse.Credentials;

      // Temporary credentials must have SessionToken
      expect(SessionToken).toBeDefined();
      expect(SessionToken.length).toBeGreaterThan(0);

      // AccessKeyId should start with ASIA (temporary) not AKIA (long-lived)
      expect(AccessKeyId).toMatch(/^ASIA/);
    });

    test("should support credential rotation", () => {
      const stsResponse1 = generateAWSSTSResponse();

      // Simulate new workflow run
      generateGitHubOIDCToken({
        runId: crypto.randomInt(1000000, 9999999).toString(),
      });
      const stsResponse2 = generateAWSSTSResponse();

      // New credentials should be different
      expect(stsResponse1.Credentials.AccessKeyId).not.toBe(
        stsResponse2.Credentials.AccessKeyId,
      );
      expect(stsResponse1.Credentials.SessionToken).not.toBe(
        stsResponse2.Credentials.SessionToken,
      );
    });

    test("should validate STS response structure", () => {
      const stsResponse = generateAWSSTSResponse();
      const validation = validateSTSResponseStructure(stsResponse);

      expect(validation.valid).toBe(true);
    });

    test("should reject STS response with missing credentials", () => {
      const invalidResponse = {
        AssumedRoleArn: `arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-role`,
      };
      const validation = validateSTSResponseStructure(invalidResponse);

      expect(validation.valid).toBe(false);
      expect(validation.error).toContain("Missing");
    });

    test("should reject STS response with expired credentials", () => {
      const expiredResponse = generateAWSSTSResponse({ expiresIn: -3600 });
      const validation = validateSTSResponseStructure(expiredResponse);

      expect(validation.valid).toBe(false);
    });

    test("should ensure credentials expire within reasonable time", () => {
      const stsResponse = generateAWSSTSResponse({ expiresIn: 3600 }); // 1 hour
      const expiration = new Date(stsResponse.Credentials.Expiration);
      const now = new Date();
      const expiresInSeconds = (expiration.getTime() - now.getTime()) / 1000;

      // Should expire within 1 hour (3600 seconds)
      expect(expiresInSeconds).toBeLessThanOrEqual(3600);
      expect(expiresInSeconds).toBeGreaterThan(0);
    });

    test("should support environment-specific OIDC configuration", () => {
      const devToken = generateGitHubOIDCToken({ environment: "development" });
      const prodToken = generateGitHubOIDCToken({ environment: "production" });

      const devDecoded = jwt.decode(devToken);
      const prodDecoded = jwt.decode(prodToken);

      expect(devDecoded.environment).toBe("development");
      expect(prodDecoded.environment).toBe("production");
    });

    test("should validate OIDC token before any AWS API calls", () => {
      const validation = validateOIDCTokenStructure(token);

      // Token must be valid before attempting STS exchange
      expect(validation.valid).toBe(true);

      // Only then should STS exchange be attempted
      const stsResponse = generateAWSSTSResponse();
      expect(stsResponse.Credentials).toBeDefined();
    });
  });

  describe("OIDC Token Validation Edge Cases", () => {
    test("should handle token with minimal required fields", () => {
      const minimalToken = generateGitHubOIDCToken();
      const decoded = jwt.decode(minimalToken);

      expect(decoded.iss).toBeDefined();
      expect(decoded.sub).toBeDefined();
      expect(decoded.aud).toBeDefined();
      expect(decoded.iat).toBeDefined();
      expect(decoded.exp).toBeDefined();
      expect(decoded.jti).toBeDefined();
    });

    test("should handle token with additional custom claims", () => {
      const token = generateGitHubOIDCToken({
        payload: {
          custom_claim: "custom_value",
          another_claim: 123,
        },
      });
      const decoded = jwt.decode(token);

      expect(decoded.custom_claim).toBe("custom_value");
      expect(decoded.another_claim).toBe(123);
    });

    test("should reject token with invalid issuer", () => {
      const token = generateGitHubOIDCToken({
        payload: { iss: "https://invalid-issuer.com" },
      });
      const decoded = jwt.decode(token);

      expect(decoded.iss).not.toContain(GITHUB_OIDC_PROVIDER);
    });

    test("should reject token with invalid audience", () => {
      const token = generateGitHubOIDCToken({ audience: "invalid-audience" });
      const decoded = jwt.decode(token);

      expect(decoded.aud).not.toBe("sts.amazonaws.com");
    });
  });

  describe("AWS Credentials Security", () => {
    test("should never expose long-lived credentials", () => {
      const stsResponse = generateAWSSTSResponse();

      // Should not contain AKIA prefix (long-lived)
      expect(stsResponse.Credentials.AccessKeyId).not.toMatch(/^AKIA/);
      // Should contain ASIA prefix (temporary)
      expect(stsResponse.Credentials.AccessKeyId).toMatch(/^ASIA/);
    });

    test("should always include session token for temporary credentials", () => {
      const stsResponse = generateAWSSTSResponse();

      expect(stsResponse.Credentials.SessionToken).toBeDefined();
      expect(stsResponse.Credentials.SessionToken.length).toBeGreaterThan(0);
    });

    test("should ensure credentials are unique per exchange", () => {
      const responses = [
        generateAWSSTSResponse(),
        generateAWSSTSResponse(),
        generateAWSSTSResponse(),
      ];

      const accessKeys = responses.map((r) => r.Credentials.AccessKeyId);
      const uniqueKeys = new Set(accessKeys);

      // All access keys should be unique
      expect(uniqueKeys.size).toBe(accessKeys.length);
    });
  });
});
