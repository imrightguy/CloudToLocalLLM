const scheduleController = require('../src/controllers/schedule.controller');

function makeRes() {
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  return { status, json };
}

// ─── createSchedule — validation only ───

describe('scheduleController.createSchedule — validation', () => {
  const validBody = {
    employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00',
  };

  it('returns 400 when any required field is missing', async () => {
    const required = ['employeeId', 'buildingId', 'dayOfWeek', 'startTime', 'endTime'];
    for (const field of required) {
      const res = makeRes();
      const body = { ...validBody };
      delete body[field];
      await scheduleController.createSchedule({ body }, res);
      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false }),
      );
    }
  });

  it('returns 400 when dayOfWeek is negative', async () => {
    const res = makeRes();
    await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: -1 } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'VALIDATION_ERROR' }) }),
    );
  });

  it('returns 400 when dayOfWeek > 6', async () => {
    const res = makeRes();
    await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: 7 } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when dayOfWeek is 100', async () => {
    const res = makeRes();
    await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: 100 } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions all required fields', async () => {
    const res = makeRes();
    await scheduleController.createSchedule({ body: {} }, res);
    const msg = res.json.mock.calls[0][0].error.message;
    expect(msg).toContain('employeeId');
    expect(msg).toContain('buildingId');
    expect(msg).toContain('dayOfWeek');
    expect(msg).toContain('startTime');
    expect(msg).toContain('endTime');
  });
});

// ─── getEmployeeAvailability — date parsing ───

describe('scheduleController.getEmployeeAvailability — date parsing', () => {
  it('returns 400 for invalid date string', async () => {
    const res = makeRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'e1', date: 'not-a-date' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'VALIDATION_ERROR' }) }),
    );
  });

  it('returns 400 for empty date', async () => {
    const res = makeRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'e1', date: '' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 for gibberish date', async () => {
    const res = makeRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'e1', date: 'abc123' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── JS getDay() → schema dayOfWeek conversion (pure logic) ───

describe('JS getDay() → schema dayOfWeek conversion', () => {
  function jsDayToSchema(jsDay) {
    return jsDay === 0 ? 6 : jsDay - 1;
  }

  it('Sunday (getDay=0) → 6', () => expect(jsDayToSchema(0)).toBe(6));
  it('Monday (getDay=1) → 0', () => expect(jsDayToSchema(1)).toBe(0));
  it('Tuesday (getDay=2) → 1', () => expect(jsDayToSchema(2)).toBe(1));
  it('Wednesday (getDay=3) → 2', () => expect(jsDayToSchema(3)).toBe(2));
  it('Thursday (getDay=4) → 3', () => expect(jsDayToSchema(4)).toBe(3));
  it('Friday (getDay=5) → 4', () => expect(jsDayToSchema(5)).toBe(4));
  it('Saturday (getDay=6) → 5', () => expect(jsDayToSchema(6)).toBe(5));
});
