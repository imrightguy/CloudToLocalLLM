const authController = require('../src/controllers/auth.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

// ─── register ──────────────────────────────────────────────────────────────

describe('register', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects empty body with 400', async () => {
    await authController.register({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing email with 400', async () => {
    await authController.register(
      { body: { password: 'Test@1234', firstName: 'Jean', lastName: 'Tremblay' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing password with 400', async () => {
    await authController.register(
      { body: { email: 'jean@test.com', firstName: 'Jean', lastName: 'Tremblay' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing firstName with 400', async () => {
    await authController.register(
      { body: { email: 'jean@test.com', password: 'Test@1234', lastName: 'Tremblay' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing lastName with 400', async () => {
    await authController.register(
      { body: { email: 'jean@test.com', password: 'Test@1234', firstName: 'Jean' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions all required fields', async () => {
    await authController.register({ body: {} }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toMatch(/email/i);
    expect(errorMsg).toMatch(/password/i);
    expect(errorMsg).toMatch(/firstName/i);
    expect(errorMsg).toMatch(/lastName/i);
  });

  it('returns error code MISSING_REQUIRED_FIELDS', async () => {
    await authController.register({ body: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'MISSING_REQUIRED_FIELDS' }),
      }),
    );
  });

  it('rejects null email with 400', async () => {
    await authController.register(
      { body: { email: null, password: 'Test@1234', firstName: 'Jean', lastName: 'Tremblay' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string email with 400', async () => {
    await authController.register(
      { body: { email: '', password: 'Test@1234', firstName: 'Jean', lastName: 'Tremblay' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects undefined email with 400', async () => {
    await authController.register(
      { body: { email: undefined, password: 'Test@1234', firstName: 'Jean', lastName: 'Tremblay' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── login ─────────────────────────────────────────────────────────────────

describe('login', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects empty body with 400', async () => {
    await authController.login({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing email with 400', async () => {
    await authController.login({ body: { password: 'Test@1234' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing password with 400', async () => {
    await authController.login({ body: { email: 'jean@test.com' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions email and password', async () => {
    await authController.login({ body: {} }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toContain('Email');
    expect(errorMsg).toContain('password');
  });

  it('returns error code MISSING_CREDENTIALS', async () => {
    await authController.login({ body: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'MISSING_CREDENTIALS' }),
      }),
    );
  });

  it('rejects null email with 400', async () => {
    await authController.login({ body: { email: null, password: 'Test@1234' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string email with 400', async () => {
    await authController.login({ body: { email: '', password: 'Test@1234' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string password with 400', async () => {
    await authController.login({ body: { email: 'jean@test.com', password: '' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── refreshAccessToken ────────────────────────────────────────────────────

describe('refreshAccessToken', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing refreshToken with 400', async () => {
    await authController.refreshAccessToken({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns error code REFRESH_TOKEN_REQUIRED', async () => {
    await authController.refreshAccessToken({ body: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'REFRESH_TOKEN_REQUIRED' }),
      }),
    );
  });

  it('error message mentions refresh token is required', async () => {
    await authController.refreshAccessToken({ body: {} }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg.toLowerCase()).toContain('refresh token');
  });

  it('rejects null refreshToken with 400', async () => {
    await authController.refreshAccessToken({ body: { refreshToken: null } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects undefined refreshToken with 400', async () => {
    await authController.refreshAccessToken({ body: { refreshToken: undefined } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string refreshToken with 400', async () => {
    await authController.refreshAccessToken({ body: { refreshToken: '' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── logout ────────────────────────────────────────────────────────────────

describe('logout', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns success without refreshToken when no user is present', async () => {
    await authController.logout({ body: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        message: 'Logged out successfully',
      }),
    );
  });

  it('does not return 400 even with empty body', async () => {
    await authController.logout({ body: {} }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('does not return 400 even with null refreshToken', async () => {
    await authController.logout({ body: { refreshToken: null } }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('returns success: true in response', async () => {
    await authController.logout({ body: {} }, res);
    const response = res.json.mock.calls[0][0];
    expect(response.success).toBe(true);
  });
});

// ─── updateProfile ─────────────────────────────────────────────────────────

describe('updateProfile', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  const mockReqWithUser = (body) => ({
    body,
    user: { id: 'user-1', email: 'existing@test.com' },
  });

  it('rejects empty body with 400', async () => {
    await authController.updateProfile(mockReqWithUser({}), res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns error code NO_FIELDS_TO_UPDATE for empty body', async () => {
    await authController.updateProfile(mockReqWithUser({}), res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'NO_FIELDS_TO_UPDATE' }),
      }),
    );
  });

  it('rejects body with unrelated fields only', async () => {
    await authController.updateProfile(mockReqWithUser({ foo: 'bar' }), res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions no fields to update', async () => {
    await authController.updateProfile(mockReqWithUser({}), res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg.toLowerCase()).toContain('no fields');
  });

  it('passes validation when firstName is provided (may hit DB)', async () => {
    await authController.updateProfile(mockReqWithUser({ firstName: 'Jean' }), res);
    // Should NOT get 400 from validation; may get 500 from DB or other status
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when lastName is provided (may hit DB)', async () => {
    await authController.updateProfile(mockReqWithUser({ lastName: 'Tremblay' }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when email is provided (may hit DB)', async () => {
    await authController.updateProfile(mockReqWithUser({ email: 'new@test.com' }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── changePassword ────────────────────────────────────────────────────────

describe('changePassword', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  const mockReqWithUser = (body) => ({
    body,
    user: { id: 'user-1' },
  });

  it('rejects missing currentPassword with 400', async () => {
    await authController.changePassword(mockReqWithUser({ newPassword: 'NewPass@1234' }), res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing newPassword with 400', async () => {
    await authController.changePassword(mockReqWithUser({ currentPassword: 'OldPass@1234' }), res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body with 400', async () => {
    await authController.changePassword(mockReqWithUser({}), res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns error code MISSING_PASSWORD_FIELDS when either is missing', async () => {
    await authController.changePassword(mockReqWithUser({ currentPassword: 'OldPass@1234' }), res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'MISSING_PASSWORD_FIELDS' }),
      }),
    );
  });

  it('error message mentions current password and new password', async () => {
    await authController.changePassword(mockReqWithUser({}), res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg.toLowerCase()).toContain('current password');
    expect(errorMsg.toLowerCase()).toContain('new password');
  });

  it('rejects newPassword shorter than 8 characters with 400', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: 'OldPass@1234', newPassword: 'Short1!' }),
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns error code WEAK_PASSWORD for short new password', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: 'OldPass@1234', newPassword: 'Ab1!' }),
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'WEAK_PASSWORD' }),
      }),
    );
  });

  it('error message for weak password mentions minimum length', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: 'OldPass@1234', newPassword: 'Ab1!' }),
      res,
    );
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg.toLowerCase()).toContain('8');
  });

  it('rejects empty string currentPassword with 400', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: '', newPassword: 'NewPass@1234' }),
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string newPassword with 400', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: 'OldPass@1234', newPassword: '' }),
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects null currentPassword with 400', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: null, newPassword: 'NewPass@1234' }),
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects null newPassword with 400', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: 'OldPass@1234', newPassword: null }),
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('passes validation when both passwords are valid and new password is 8+ chars', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: 'OldPass@1234', newPassword: 'NewValid1!' }),
      res,
    );
    // Should NOT get 400 from validation; may get 500 from DB
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('exactly 8 character new password passes length validation', async () => {
    await authController.changePassword(
      mockReqWithUser({ currentPassword: 'OldPass@1234', newPassword: 'NewPw!12' }),
      res,
    );
    // Should NOT get 400 for length; may get 500 from DB
    if (res.status.mock.calls.length > 0) {
      expect(res.status).not.toHaveBeenCalledWith(400);
    }
  });
});

// ─── deleteUser ────────────────────────────────────────────────────────────

describe('deleteUser', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('prevents self-deletion with 400', async () => {
    const userId = 'user-1';
    await authController.deleteUser(
      { params: { id: userId }, user: { id: userId } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns error code CANNOT_DELETE_SELF', async () => {
    const userId = 'user-1';
    await authController.deleteUser(
      { params: { id: userId }, user: { id: userId } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'CANNOT_DELETE_SELF' }),
      }),
    );
  });

  it('error message mentions cannot deactivate own account', async () => {
    const userId = 'user-1';
    await authController.deleteUser(
      { params: { id: userId }, user: { id: userId } },
      res,
    );
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg.toLowerCase()).toContain('cannot');
  });

  it('allows deletion when target id differs from user id (may hit DB)', async () => {
    await authController.deleteUser(
      { params: { id: 'user-2' }, user: { id: 'user-1' } },
      res,
    );
    // Should NOT get 400 from self-deletion check; may get 500 from DB
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── updateUser ────────────────────────────────────────────────────────────

describe('updateUser', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  const mockReqWithParams = (body) => ({
    params: { id: 'user-1' },
    body,
  });

  it('rejects empty body with 400', async () => {
    await authController.updateUser(mockReqWithParams({}), res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns error code NO_FIELDS_TO_UPDATE for empty body', async () => {
    await authController.updateUser(mockReqWithParams({}), res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'NO_FIELDS_TO_UPDATE' }),
      }),
    );
  });

  it('rejects body with unrelated fields only', async () => {
    await authController.updateUser(mockReqWithParams({ foo: 'bar', baz: 42 }), res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions no fields to update', async () => {
    await authController.updateUser(mockReqWithParams({}), res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg.toLowerCase()).toContain('no fields');
  });

  it('passes validation when firstName is provided (may hit DB)', async () => {
    await authController.updateUser(mockReqWithParams({ firstName: 'Jean' }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when lastName is provided (may hit DB)', async () => {
    await authController.updateUser(mockReqWithParams({ lastName: 'Tremblay' }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when email is provided (may hit DB)', async () => {
    await authController.updateUser(mockReqWithParams({ email: 'new@test.com' }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when role is provided (may hit DB)', async () => {
    await authController.updateUser(mockReqWithParams({ role: 'admin' }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when isActive is provided (may hit DB)', async () => {
    await authController.updateUser(mockReqWithParams({ isActive: true }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when phone is provided (may hit DB)', async () => {
    await authController.updateUser(mockReqWithParams({ phone: '514-555-0001' }), res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('passes validation when multiple fields are provided (may hit DB)', async () => {
    await authController.updateUser(
      mockReqWithParams({ firstName: 'Jean', lastName: 'Tremblay', role: 'manager' }),
      res,
    );
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});
